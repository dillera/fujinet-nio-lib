/* Network transport (4): the NIO device runs inside NioLib, on the Palm, and reaches the Internet through the Palm's
 * own network library (NetLib): PPP over Bluetooth to a gateway, Wi-Fi, a modem or a cradle, whichever service the
 * Network preferences select. No FujiNet hardware is involved: each request packet goes to the NIO core in
 * netlib/ (NetworkDevice tcp:// and http://, FujiDevice info, WiFiDevice status), which answers it as a FujiNet
 * would. The core's state (about 6 KB) is allocated for one foreground client session only, so the library's global
 * data stays small whichever transport is chosen. */
#include "private.h"
#include "fn_internal.h"
#include "netlib/nio.h"

static NioState *nl_nio;
#define nl_on (nl_nio != NULL)

/* NetLib is present: no proof of a configured service, a link or the Internet. */
UInt16 nl_netlib_available(void)
{
    UInt16 ref;
    return SysLibFind("Net.lib", &ref) == errNone;
}

UInt16 nl_netlib_open(void)
{
    NioState *nio;
    if (nl_on) return FN_OK;
    if (!nl_netlib_available()) return FN_ERR_NOT_FOUND;
    nio = MemPtrNew(sizeof(NioState));
    if (!nio) return FN_ERR_IO;
    MemPtrSetOwner(nio, 0);             /* the library's, not the app's: freed at close */
    nio_init(nio);
    nl_nio = nio;
    return FN_OK;
}

void nl_netlib_close(void)
{
    /* Closes every socket; NetLib keeps the link for its idle time, so the next app need not dial again. */
    if (!nl_on) return;
    nio_shutdown(nl_nio);
    MemPtrFree(nl_nio);
    nl_nio = NULL;
}

UInt16 nl_netlib_ready(void) { return nl_on; }

UInt16 nl_netlib_exchange(const UInt8 *request, UInt16 length, UInt8 *response, UInt16 capacity, UInt16 *got)
{
    *got = 0;
    if (!nl_on) return FN_ERR_NOT_READY;
    *got = nio_exchange(nl_nio, request, length, response, capacity);
    return *got ? FN_OK : FN_ERR_INVALID;
}

/* The link and the counters, for NIO Config. While no client session is open the core has no state: then only
 * whether NetLib is open (by anyone) and its address are known. */
void nl_netlib_status(NioLibNetLibStatus *s)
{
    UInt16 ref = 0, count = 0;
    s->flags = 0;
    s->sessions = 0;
    s->connects = s->failures = 0;
    s->bytesIn = s->bytesOut = 0;
    s->ip[0] = 0;
    if (!nl_netlib_available()) return;
    s->flags |= nioNetLibPresent;
    if (nl_on) {
        s->flags |= nioNetLibSession;
        if (nl_nio->net_up) s->flags |= nioNetLibUp;
        s->sessions = nio_sessions_open(nl_nio);
        s->connects = nl_nio->net.connects;
        s->failures = nl_nio->net.failures;
        s->bytesIn = nl_nio->net.bytesIn;
        s->bytesOut = nl_nio->net.bytesOut;
        if (nl_nio->net_up) nio_sock_local_ip(&nl_nio->net, s->ip, sizeof(s->ip));
        return;
    }
    if (SysLibFind("Net.lib", &ref) == errNone && NetLibOpenCount(ref, &count) == errNone && count) {
        NioNet probe;
        MemSet(&probe, sizeof(probe), 0);
        probe.ref = ref;
        probe.open = 1;
        s->flags |= nioNetLibUp;
        nio_sock_local_ip(&probe, s->ip, sizeof(s->ip));
    }
}

/* NIO Config's Disconnect: the link goes now, not after NetLib's idle time. Only when no client owns the library. */
Err nl_netlib_hangup(void)
{
    UInt16 ref = 0, count = 0;
    if (nl_on) return nioLibErrBusy;
    if (SysLibFind("Net.lib", &ref) || NetLibOpenCount(ref, &count) || !count) return errNone;
    /* Opened by someone and now idle in its close-wait: open once more and close at once. */
    {
        UInt16 ifErrs = 0;
        Err err = NetLibOpen(ref, &ifErrs);
        if (err == errNone || err == netErrAlreadyOpen) NetLibClose(ref, true);
    }
    return errNone;
}
