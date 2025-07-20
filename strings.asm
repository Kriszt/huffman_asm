; Gyurka Krisztian gkim2237 531

%include 'io.inc'

global StrLen, StrCat, StrCpy, StrUpper, StrLower, StrCompact
section .text

; ESI -> EAX
StrLen:
    xor eax, eax

.loop:
    cmp byte [esi + eax], 0
    je .done

    inc eax
    jmp .loop

.done:
    ret

; EDI, ESI -> ()
StrCat:
    push edi
    push esi

    xchg edi, esi
    call StrLen
    xchg edi, esi
    add edi, eax

.loop:
    mov eax, [esi]
    cmp al, 0
    je .done

    mov [edi], al
    inc edi
    inc esi
    jmp .loop

.done:
    mov byte [edi], 0
    pop edi
    pop esi
    ret

; ESI -> ()
StrUpper:
    push esi

.loop:
    mov al, [esi]
    cmp al, 0
    je .done

    cmp al, 'a'
    jl .skip
    cmp al, 'z'
    jg .skip

    sub al, 32
    mov [esi], al

.skip:
    inc esi
    jmp .loop

.done:
    pop esi
    ret

; ESI -> ()
StrLower:
    push esi

.loop:
    mov al, [esi]
    cmp al, 0
    je .done

    cmp al, 'A'
    jl .skip
    cmp al, 'Z'
    jg .skip

    add al, 32
    mov [esi], al

.skip:
    inc esi
    jmp .loop

.done:
    pop esi
    ret

; ESI, EDI -> ()
StrCompact:
    push esi
    push edi

.loop:
    mov al, [esi]
    cmp al, 0
    je .done

    cmp al, 32
    je .skip
    cmp al, 9
    je .skip
    cmp al, 13
    je .skip
    cmp al, 10
    je .skip

    mov [edi], al
    inc edi

.skip:
    inc esi
    jmp .loop

.done:
    mov byte [edi], 0
    pop esi
    pop edi
    ret


