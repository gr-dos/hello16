; hello - print a greeting
;
; 8086 assembly version of hello.c for MS-DOS, built as a .COM with
; NASM.  It reproduces hello.exe's observable behavior: the same bytes
; on standard output and standard error (CR LF line endings), the same
; exit status, and the same splitting of the command tail into
; arguments.  Only the first argument matters, so only it is parsed.
;
; Build: nasm -f bin -DVERSION='"0.01"' -o hello.com hello.asm

        cpu     8086
        org     100h

%ifndef VERSION
%define VERSION 'unknown'
%endif

start:
        cld

        ; Find the first argument in the command tail (PSP:80h holds its
        ; length, PSP:81h the text).  Arguments are split the way libc16
        ; splits them for hello.exe, which is Microsoft C's rule:
        ;   - blanks (space, tab) separate arguments;
        ;   - " toggles quoting and is removed; blanks inside quotes are
        ;     kept;
        ;   - a run of 2n backslashes before " gives n backslashes and a
        ;     toggle; 2n + 1 give n backslashes and a literal ";
        ;   - any other \ is literal.
        ; The argument is unquoted in place; DX:DI brackets the result.
        mov     si, 81h
        mov     cl, [80h]
        xor     ch, ch
.skip:  jcxz    .none
        lodsb
        dec     cx
        cmp     al, ' '
        je      .skip
        cmp     al, 9
        je      .skip
        dec     si
        inc     cx
        mov     di, si
        mov     dx, si
        xor     bl, bl                  ; BL = 1 inside quotes
.next:  jcxz    .end
        lodsb
        dec     cx
        cmp     al, '\'
        jne     .notbs
        mov     ah, 1                   ; AH = backslashes in the run
.run:   jcxz    .lit
        lodsb
        cmp     al, '\'
        jne     .runend
        dec     cx
        inc     ah
        jmp     .run
.runend:
        dec     si                      ; leave the byte after the run
        cmp     al, '"'
        jne     .lit
        shr     ah, 1                   ; AH = n
        sbb     bh, bh                  ; BH = -1 for 2n + 1
        mov     al, '\'
.half:  test    ah, ah
        jz      .quote
        stosb
        dec     ah
        jmp     .half
.quote: test    bh, bh
        jz      .next                   ; 2n: the " toggles, read next
        movsb                           ; 2n + 1: a literal "
        dec     cx
        jmp     .next
.lit:   mov     al, '\'                 ; no " follows: all literal
.lits:  stosb
        dec     ah
        jnz     .lits
        jmp     .next
.none:  jmp     greet                   ; no argument
.notbs: cmp     al, '"'
        jne     .notq
        xor     bl, 1
        jmp     .next
.notq:  test    bl, bl
        jnz     .copy
        cmp     al, ' '
        je      .end
        cmp     al, 9
        je      .end
.copy:  stosb
        jmp     .next
.end:   mov     bx, di
        sub     bx, dx                  ; BX = argument length

        ; match it against the options
        mov     si, options
.opt:   lodsb
        test    al, al
        jz      bad
        mov     cl, al
        xor     ch, ch
        mov     di, dx
        cmp     cx, bx
        jne     .no
        repe    cmpsb
        je      .yes
.no:    add     si, cx
        jmp     .opt
.yes:   cmp     si, opt_version_end
        jne     help

version:
        mov     dx, msg_version
        mov     cx, msg_version_len
        jmp     out

help:
        mov     dx, msg_help
        mov     cx, msg_help_len
        jmp     out

greet:
        mov     dx, msg_hello
        mov     cx, msg_hello_len
out:    mov     bx, 1
        call    write
        mov     ax, 4C00h
        jmp     exit

        ; "hello: unrecognized option 'ARG'" if ARG starts with -,
        ; otherwise "hello: extra operand 'ARG'"
bad:    mov     si, dx                  ; SI = argument, BX = length
        push    bx
        mov     dx, msg_extra
        mov     cx, msg_extra_len
        test    bx, bx
        jz      .say
        cmp     byte [si], '-'
        jne     .say
        mov     dx, msg_option
        mov     cx, msg_option_len
.say:   mov     bx, 2
        call    write
        mov     dx, si
        pop     cx
        call    write
        mov     dx, msg_try
        mov     cx, msg_try_len
        call    write
        mov     ax, 4C01h
exit:   int     21h
        int     20h                     ; DOS 1.x has no function 4Ch

        ; write CX bytes at DX to handle BX
write:  mov     ah, 40h
        int     21h
        ret

options:
        db      9, '--version'
opt_version_end:
        db      6, '--help'
        db      2, '-h'
        db      2, '-?'
        db      0

msg_hello:
        db      'Hello, world!', 13, 10
msg_hello_len equ $ - msg_hello

msg_version:
        db      'hello (dos-hello16) ', VERSION, 13, 10
msg_version_len equ $ - msg_version

msg_help:
        db      'Usage: hello [OPTION]...', 13, 10
        db      'Print a greeting.', 13, 10
        db      13, 10
        db      '  -h, --help     display this help and exit', 13, 10
        db      '      --version  output version information and exit', 13, 10
msg_help_len equ $ - msg_help

msg_option:
        db      "hello: unrecognized option '"
msg_option_len equ $ - msg_option

msg_extra:
        db      "hello: extra operand '"
msg_extra_len equ $ - msg_extra

msg_try:
        db      "'", 13, 10
        db      "Try 'hello --help' for more information.", 13, 10
msg_try_len equ $ - msg_try
