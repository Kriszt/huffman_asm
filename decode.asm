; Gyurka Krisztian gkim2237 531

%include "io.inc"
%include "strings.asm"

section .data
    dir_path db 'C:\Users\Krisztian\Desktop\test',0
    current_dir db '.\*',0
    parent_dir db '..',0
    tab db 9,0
    zero db '0',0
    one db '1',0
    diff_chars db 'number of different characters: ',0
    MAX_PATH equ 260
    READ_BUFFER_SIZE equ 40960000
    ALPHABET equ 256
    compressed_name db 'compressed',0
    created db '-created',0


section .bss
    find_data resb 320 ; WIN32_FIND_DATA structure
    pwd resb 260
    start_path resb 260
    file_handle resd 1
    compressed_handle resd 1
    bytes_read resd 1
    bytes_written resd 1
    mem_ptr resd 1
    encoded_ptr resd 1
    process_heap resd 1
    freq_table resd 256
    char resb 2
    n resb 1 ; number of different characters
    tree_ptr resd 1 ; address of the tree
    tree_root resd 1
    mode resb 1 ; 0 - count chars, 1 - write encoded text to a file
    fullname resb 260
    length resd 1
    high_addr resd 1
    old_tree_ptr resd 1
    character resb 1
    total_chars resb 1
    


section .text
    extern _FindFirstFileA@8
    extern _FindNextFileA@8
    extern _FindClose@4
    extern _SetCurrentDirectoryA@4
    extern _GetCurrentDirectoryA@8
    extern _GetLastError@0
    extern _WriteConsoleA@20
    extern _GetStdHandle@4
    extern _ExitProcess@4
    extern _CreateFileA@28
    extern _HeapAlloc@12
    extern _HeapFree@12
    extern _GetProcessHeap@0
    extern _ReadFile@20
    extern _WriteFile@20
    extern _CloseHandle@4
    extern _GetFullPathNameA@16

global main

main:
    ; Get process heap for memory allocation
    call _GetProcessHeap@0
    test eax, eax
    je error
    mov [process_heap], eax

    ; get starting directory
    push start_path
    push MAX_PATH
    call _GetCurrentDirectoryA@8
    mov eax, start_path

    ; Create the compressed file for reading
    push 0
    push 128 ; FILE_ATTRIBUTE_NORMAL
    push 3 ; OPEN_EXISTING
    push 0
    push 0
    push 0x80000000 ; GENERIC_READ
    push compressed_name ; filename
    call _CreateFileA@28
    cmp eax, -1
    je error
    mov [compressed_handle], eax

    call read_tree
    call print_tree

    ; allocate memory for file content
    push READ_BUFFER_SIZE
    push 0x00000008 ; HEAP_ZERO_MEMORY
    push dword [process_heap]
    call _HeapAlloc@12
    test eax, eax
    je error
    mov [mem_ptr], eax

    call read_compressed

    ; Close compressed file
    ; free the memory
    push dword [mem_ptr]
    push 0
    push dword [process_heap]
    call _HeapFree@12
    test eax, eax
    je error    

read_tree:
    ; old tree address
    push 0
    push bytes_read
    push 4
    push old_tree_ptr
    push dword [compressed_handle]
    call _ReadFile@20
    test eax, eax
    je error

    ; tree length
    push 0
    push bytes_read
    push 4
    push length
    push dword [compressed_handle]
    call _ReadFile@20
    test eax, eax
    je error
    mov eax, dword [length]

    push dword [length]
    push 0x00000008 ; HEAP_ZERO_MEMORY
    push dword [process_heap]
    call _HeapAlloc@12
    test eax, eax
    je error
    mov [tree_ptr], eax

    ; tree
    push 0
    push bytes_read
    push dword [length]
    push dword [tree_ptr]
    push dword [compressed_handle]
    call _ReadFile@20
    test eax, eax
    je error

    mov edx, dword [old_tree_ptr]
    sub edx, dword [tree_ptr]
    mov ecx, dword [length]
    shr ecx, 4 
    mov ebx, [tree_ptr]
.subdiff:
    cmp [ebx+4], dword 0
    je .left
    sub [ebx+4], edx
.left:
    cmp [ebx+8], dword 0
    je .right
    sub [ebx+8], edx
.right:
    cmp [ebx+12], dword 0
    je .skip
    sub [ebx+12], edx
.skip:
    add ebx, 16
    loop .subdiff

    mov eax, dword [tree_ptr]
    add eax, dword [length]
    sub eax, 16
    mov [tree_root], eax

    jmp end

read_compressed:
    ; mov eax, ecx
    ; call io_writeint
    ; call io_writeln
    ; mov eax, dword [total_chars]
    ; call io_writeint
    ; call io_writeln
    ; filename length
    push 0
    push bytes_read
    push 4
    push length
    push dword [compressed_handle]
    call _ReadFile@20
    mov ebx, [bytes_read]
    test ebx, ebx
    je end
    test eax, eax
    je error

    ; filename
    push 0
    push bytes_read
    push dword [length]
    push dword [mem_ptr]
    push dword [compressed_handle]
    call _ReadFile@20
    test eax, eax
    je error

    ; null terminate filename
    mov ebx, [mem_ptr]
    add ebx, dword [length]
    mov [ebx], byte 0
    mov ebx, [mem_ptr]
    ; add created- to the start of it
    ; mov edi, ebx
    ; mov esi, created
    ; call StrCat
    mov eax, ebx
    call io_writestr
    call io_writeln

    ; create the file
    push 0
    push 128 ; FILE_ATTRIBUTE_NORMAL
    push 2 ; CREATE_ALWAYS
    push 0
    push 0
    push 0x40000000 ; GENERIC_WRITE
    push ebx ; filename
    call _CreateFileA@28
    cmp eax, -1
    je error
    mov [file_handle], eax

    ; compressed length
    push 0
    push bytes_read
    push 4
    push length
    push dword [compressed_handle]
    call _ReadFile@20
    test eax, eax
    je error

    ; char count
    push 0
    push bytes_read
    push 4
    push total_chars
    push dword [compressed_handle]
    call _ReadFile@20
    test eax, eax
    je error

    ; compressed
    push 0
    push bytes_read
    push dword [length]
    push dword [mem_ptr]
    push dword [compressed_handle]
    call _ReadFile@20
    test eax, eax
    je error

    mov ecx, dword [bytes_read]
    mov ebx, [mem_ptr]
    mov edx, [tree_root]
    mov eax, dword 4096
    add eax, dword [tree_ptr]
    mov [high_addr], eax
    xor eax, eax

.next:
    test ecx, ecx
    jz .write
    dec ecx
    mov edi, dword 8
    movzx eax, byte [ebx]
    inc ebx
.process:
    cmp edx, [high_addr]
    jl .write
    mov esi, edx
    test edi, edi
    jz .next
    dec edi
    shl al, 1
    jc .left
    mov edx, [edx+8]
    jmp .process

.left:
    mov edx, [edx+12]
    jmp .process

.write:
    push eax
    sub edx, [tree_ptr]
    shr edx, 4
    mov [character], dl

    push ecx
    push 0
    push bytes_written
    push dword 1 ; length
    push character
    push dword [file_handle]
    call _WriteFile@20
    test eax, eax
    jz error
    pop ecx
    pop eax

    dec dword [total_chars]
    cmp [total_chars], dword 0
    je read_compressed

    mov edx, [tree_root]
    jmp .process
    
print_tree:
    mov eax, [tree_root]
    add eax, 16
    sub eax, [tree_ptr]
    shr eax, 4
    mov ecx, eax

    mov ebx, [tree_ptr]
    mov edx, ecx
.loopx:
    mov eax, edx
    sub eax, ecx
    call io_writeint
    mov eax, tab
    call io_writestr
    mov eax, ebx
    call io_writehex
    mov eax, tab
    call io_writestr
    mov eax, [ebx+4]
    call io_writehex
    mov eax, tab
    call io_writestr
    mov eax, [ebx+8]
    call io_writehex
    mov eax, tab
    call io_writestr
    mov eax, [ebx+12]
    call io_writehex
    call io_writeln
    add ebx, 16
    loop .loopx

    jmp end

error:
    call _GetLastError@0
    call io_writeint
    call io_writeln
end:
    xor eax, eax
    ret