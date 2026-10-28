/* Differential C callers execute on a 6502, checking the cc65 ABI as well as
 * packet bytes. Reference implementations are compiled from common sources. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "fn_internal.h"
#include "fn_raw.h"
uint16_t ref_fold(const uint8_t *,uint16_t,uint16_t);
uint8_t ref_checksum(const uint8_t *,uint16_t);
uint8_t ref_packet_checksum(const uint8_t *,uint16_t);
uint16_t ref_header(uint8_t *,uint8_t,uint8_t,uint16_t);
uint16_t ref_param(uint8_t *,uint8_t,uint32_t,uint8_t);
uint8_t ref_parse(void);
uint16_t ref_open(uint8_t *,uint8_t,uint8_t,const char *);
uint16_t ref_read(uint8_t *,fn_handle_t,uint32_t,uint16_t);
uint16_t ref_write(uint8_t *,fn_handle_t,uint32_t,const uint8_t *,uint16_t);
uint16_t ref_close(uint8_t *,fn_handle_t);
uint16_t ref_info(uint8_t *,fn_handle_t);
uint16_t ref_ready_packet(uint8_t *);
uint8_t ref_raw(uint8_t,uint8_t,const void *,uint16_t,void *,uint16_t,fn_raw_response_t *);
uint8_t ref_init(void);
static unsigned checks;
#define CHECK(c) do { ++checks; if (!(c)) { printf("FAIL line %u check %u\n",__LINE__,checks); exit(1); } } while(0)
static uint8_t a[1100], b[1100], packet[512], payload[512], reply[512], reply_ref[512];
static char url[130];
static fn_parse_ctx_t saved, expected;
static uint16_t wire_len, requests, sent_len;
static uint8_t transport_result, sent[512];
static uint8_t init_result, ready_result=1;
static uint16_t init_calls;
static fn_session_t expected_sessions[FN_MAX_SESSIONS];
uint8_t fn_transport_init(void) { ++init_calls; return init_result; }
uint8_t fn_transport_ready(void) { return ready_result; }
static void fresh_state(void) {
    _fn_initialized=0;
    memset(_fn_sessions,0xa9,sizeof(_fn_sessions));
    memset(_fn_req_buf,0x71,sizeof(_fn_req_buf));
    memset(_fn_resp_buf,0x72,sizeof(_fn_resp_buf));
    memset(&_fn_parse_ctx,0x73,sizeof(_fn_parse_ctx));
    memset(&_fn_transport_ctx,0x74,sizeof(_fn_transport_ctx));
    init_calls=requests=sent_len=0;
}
static void init_cases(void) {
    uint8_t initialized,ready,error,x,y,after;
    uint16_t calls;
    for(initialized=0;initialized<2;++initialized)
        for(ready=0;ready<2;++ready)
            for(error=0;error<2;++error) {
                init_result=error?FN_ERR_TRANSPORT:FN_OK;ready_result=ready;
                fresh_state();_fn_initialized=initialized;
                x=ref_init();calls=init_calls;after=_fn_initialized;
                memcpy(expected_sessions,_fn_sessions,sizeof(_fn_sessions));
                fresh_state();_fn_initialized=initialized;
                y=fn_init();
                CHECK(x==y);CHECK(init_calls==calls);CHECK(_fn_initialized==after);
                CHECK(memcmp(expected_sessions,_fn_sessions,sizeof(_fn_sessions))==0);
                /* Independently require every byte except active to survive. */
                expected_sessions[0].active=0xa9;expected_sessions[1].active=0xa9;
                memset(a,0xa9,sizeof(_fn_sessions));
                CHECK(memcmp(a,expected_sessions,sizeof(_fn_sessions))==0);
                if(!initialized && error) {
                    CHECK(_fn_initialized==0);init_result=0;
                    CHECK(fn_init()==0);CHECK(_fn_initialized==1);CHECK(init_calls==2);
                    CHECK(_fn_sessions[0].active==0 && _fn_sessions[1].active==0);
                }
            }
    init_result=0;ready_result=1;
}

uint8_t fn_transport_exchange(void) {
    ++requests;
    sent_len=_fn_transport_ctx.req_len;
    memcpy(sent,_fn_transport_ctx.request,sent_len);
    memcpy(_fn_transport_ctx.response,packet,wire_len);
    _fn_transport_ctx.resp_len=wire_len;
    return transport_result;
}
static void reset(void) { memset(a,0xa5,sizeof(a));memset(b,0xa5,sizeof(b)); }
static void equal(uint16_t x,uint16_t y) { CHECK(x==y);CHECK(memcmp(a,b,sizeof(a))==0); }
static void parse_case(uint16_t n) {
    uint8_t x,y;
    memset(&_fn_parse_ctx,0x5a,sizeof(_fn_parse_ctx));
    _fn_parse_ctx.response=packet;_fn_parse_ctx.resp_len=n;saved=_fn_parse_ctx;
    x=ref_parse();expected=_fn_parse_ctx;_fn_parse_ctx=saved;
    y=fn_parse_response_header();
    if(x!=y || memcmp(&expected,&_fn_parse_ctx,sizeof(expected))) {
        printf("parse n=%u desc=%u x=%u y=%u status=%u/%u\n",n,packet[5],x,y,expected.status,_fn_parse_ctx.status);
        CHECK(0);
    }
    ++checks;
}
static void checksum_packet(uint16_t n) { packet[2]=(uint8_t)n;packet[3]=(uint8_t)(n>>8);packet[4]=ref_packet_checksum(packet,n); }
static void raw_case(uint16_t length,uint8_t null_payload,uint16_t capacity,uint8_t null_reply,uint8_t null_response) {
    uint8_t x,y;
    fn_raw_response_t r,s;
    uint16_t calls, n;
    memset(reply,0xa6,sizeof(reply));memset(reply_ref,0xa6,sizeof(reply_ref));
    r.status=s.status=99;r.payload_length=s.payload_length=99;
    fresh_state();
    x=ref_raw(0xfc,0x42,null_payload?0:payload,length,null_reply?0:reply_ref,capacity,null_response?0:&r);
    calls=requests;n=sent_len;memcpy(a,sent,n);
    memcpy(expected_sessions,_fn_sessions,sizeof(_fn_sessions));
    fresh_state();
    y=fn_raw_call(0xfc,0x42,null_payload?0:payload,length,null_reply?0:reply,capacity,null_response?0:&s);
    CHECK(x==y);CHECK(calls==requests);CHECK(requests<=1);
    CHECK(init_calls==1);CHECK(_fn_initialized==1);
    CHECK(memcmp(expected_sessions,_fn_sessions,sizeof(_fn_sessions))==0);
    CHECK(memcmp(&r,&s,sizeof(r))==0);CHECK(memcmp(reply,reply_ref,sizeof(reply))==0);
    if(requests) {CHECK(n==sent_len);CHECK(memcmp(a,sent,n)==0);}
}
static void alias_case(uint16_t n) {
    fn_raw_response_t r,s;
    uint8_t x,y;
    fresh_state();memcpy(_fn_resp_buf,payload,n);
    x=ref_raw(0xfc,0x42,_fn_resp_buf,n,_fn_req_buf,n,&r);
    memcpy(a,_fn_req_buf,sizeof(_fn_req_buf));
    memcpy(b,sent,sent_len);
    fresh_state();memcpy(_fn_resp_buf,payload,n);
    y=fn_raw_call(0xfc,0x42,_fn_resp_buf,n,_fn_req_buf,n,&s);
    CHECK(x==0 && y==0);CHECK(requests==1);
    CHECK(memcmp(a,_fn_req_buf,sizeof(_fn_req_buf))==0);
    CHECK(memcmp(b,sent,sent_len)==0);CHECK(memcmp(&r,&s,sizeof(r))==0);
    CHECK(s.payload_length==n);CHECK(memcmp(_fn_req_buf,packet+6,n)==0);
}

int main(void) {
    uint16_t i,n,seed;uint8_t d,k;
    init_cases();
    for(i=0;i<sizeof(payload);++i) payload[i]=(uint8_t)(i*37+19);
    for(n=0;n<=512;n+=n<8?1:31) {
        for(i=0;i<8;++i) {
            seed=i==0?0:i==1?0x1ff:i==2?0xffff:(uint16_t)(i*9011);
            CHECK(fn_checksum_fold(payload,n,seed)==ref_fold(payload,n,seed));
        }
        CHECK(fn_calc_checksum(payload,n)==ref_checksum(payload,n));
        CHECK(fn_calc_packet_checksum(payload,n)==ref_packet_checksum(payload,n));
    }
    for(i=0;i<4;++i) {
        n=i==0?255:i==1?256:i==2?511:512;
        CHECK(fn_checksum_fold(payload,n,0x1ff)==ref_fold(payload,n,0x1ff));
        CHECK(fn_checksum_fold(payload,n,0xffff)==ref_fold(payload,n,0xffff));
        CHECK(fn_calc_checksum(payload,n)==ref_checksum(payload,n));
        CHECK(fn_calc_packet_checksum(payload,n)==ref_packet_checksum(payload,n));
    }
    for(i=0;i<256;++i) {
        reset();equal(fn_build_header(a,(uint8_t)i,(uint8_t)~i,i*257),ref_header(b,(uint8_t)i,(uint8_t)~i,i*257));
        reset();equal(fn_add_param(a,(uint8_t)i,0x1234abcdUL,(uint8_t)i),ref_param(b,(uint8_t)i,0x1234abcdUL,(uint8_t)i));
    }
    for(i=0;i<=129;++i) {
        memset(url,'x',i);url[i]=0;
        reset();equal(fn_build_open_packet(a,3,0xa7,url),ref_open(b,3,0xa7,url));
    }
    for(i=0;i<12;++i) {
        n=i*41;
        reset();equal(fn_build_read_packet(a,0xabcd,0x98765432UL,n),ref_read(b,0xabcd,0x98765432UL,n));
        reset();equal(fn_build_write_packet(a,0xabcd,0x98765432UL,payload,n),ref_write(b,0xabcd,0x98765432UL,payload,n));
        reset();equal(fn_build_write_packet(a,0xabcd,0x98765432UL,0,n),ref_write(b,0xabcd,0x98765432UL,0,n));
        reset();equal(fn_build_close_packet(a,n),ref_close(b,n));
        reset();equal(fn_build_info_packet(a,n),ref_info(b,n));
    }
    reset();equal(fn_build_ready_packet(a),ref_ready_packet(b));   /* the Ready request: assembly against the C original */
    for(i=0;i<8;++i) {
        uint16_t h;
        uint32_t offset;
        h=i==0?0:i==1?0xffffu:(uint16_t)(i*8191u);
        offset=i==0?0:i==1?0xffffffffUL:0x01020408UL*i;
        reset();equal(fn_build_read_packet(a,h,offset,512),ref_read(b,h,offset,512));
        reset();equal(fn_build_read_packet(a,h,offset,65535u),ref_read(b,h,offset,65535u));
        reset();equal(fn_build_write_packet(a,h,offset,payload,497),ref_write(b,h,offset,payload,497));
    }
    for(i=0;i<256;++i) {
        for(n=0;n<18;++n) {
            memset(packet,0x23,sizeof(packet));packet[5]=(uint8_t)i;
            checksum_packet(n);parse_case(n);
        }
    }
    for(k=0;k<8;++k) {
        for(n=250;n<=512;n+=n==512?1:1) {
            memset(packet,0x80,sizeof(packet));packet[5]=0x80;
            packet[n-5]=k;checksum_packet(n);parse_case(n);
        }
    }
    memset(packet,0,sizeof(packet));packet[0]=0xfc;packet[1]=0x42;wire_len=32;checksum_packet(wire_len);
    for(i=0;i<8;++i) {
        n=i==0?0:i==1?1:i==2?255:i==3?256:i==4?506:i==5?507:i==6?65535u:32;
        raw_case(n,0,512,0,0);raw_case(n,1,512,0,0);
    }
    raw_case(1,0,512,1,0);raw_case(1,0,512,0,1);raw_case(1,0,26,0,0);raw_case(1,0,25,0,0);
    for(d=1;d<20;++d) { transport_result=d;raw_case(1,0,512,0,0); }transport_result=0;
    for(i=0;i<256;++i) {
        packet[5]=(uint8_t)i;checksum_packet(wire_len);raw_case(1,0,512,0,0);
    }
    for(wire_len=0;wire_len<6;++wire_len) raw_case(1,0,512,0,0);
    wire_len=32;packet[5]=0;checksum_packet(wire_len);
    packet[0]^=1;raw_case(1,0,512,0,0);packet[0]^=1;
    packet[1]^=1;raw_case(1,0,512,0,0);packet[1]^=1;
    packet[2]^=1;raw_case(1,0,512,0,0);parse_case(wire_len);packet[2]^=1;
    packet[4]^=1;raw_case(1,0,512,0,0);parse_case(wire_len);
    for(i=0;i<3;++i) {
        n=i==0?255:i==1?256:506;
        memcpy(packet+6,payload,n);packet[0]=0xfc;packet[1]=0x42;packet[5]=0;
        wire_len=n+6;checksum_packet(wire_len);
        raw_case(n,0,n,0,0);
        CHECK(memcmp(reply,packet+6,n)==0);CHECK(reply[n]==0xa6);
        raw_case(n,0,n-1,0,0);
        for(seed=0;seed<sizeof(reply);++seed) CHECK(reply[seed]==0xa6);
        alias_case(n);
    }
    printf("Atari compact differential: %u checks passed\n",checks);
    return 0;
}
