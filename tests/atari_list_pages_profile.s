        .export _profile_list_pages, profile_start, profile_done
        .import _fn_file_list_pages
        .segment "CODE"
_profile_list_pages:
profile_start:
        jsr _fn_file_list_pages
profile_done:
        rts
