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
    character resb 1
    total_chars resd 1
    


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

    ; Create the compressed file for writing
    push 0
    push 128 ; FILE_ATTRIBUTE_NORMAL
    push 2 ; CREATE_ALWAYS
    push 0
    push 0
    push 0x40000000 ; GENERIC_WRITE
    push compressed_name ; filename
    call _CreateFileA@28
    cmp eax, -1
    je error
    mov [compressed_handle], eax
    
    ; Set the pwd to the given directory
    mov esi, dir_path
    push esi
    call _SetCurrentDirectoryA@4
    test eax, eax
    jz error

    ; Start listing files and counting characters
    mov [mode], byte 0
    call list_files

    ; mov ecx, 256
    ; call print_table
    ; mov eax, diff_chars
    ; call io_writestr
    ; mov eax, [n]
    ; call io_writeint
    ; call io_writeln

    call build_tree
    call print_code
    ; call print_tree

    ; write tree address to file
    push 0
    push bytes_written
    push dword 4 ; length
    push tree_ptr
    push dword [compressed_handle]
    call _WriteFile@20
    test eax, eax
    jz error

    ; write tree length in bytes to file
    mov eax, [tree_root]
    add eax, 16
    sub eax, [tree_ptr]
    mov [length], eax

    push 0
    push bytes_written
    push dword 4 ; length
    push length
    push dword [compressed_handle]
    call _WriteFile@20
    test eax, eax
    jz error

    ; write tree to file
    push 0
    push bytes_written
    push dword [length] ; length
    push dword [tree_ptr]
    push dword [compressed_handle]
    call _WriteFile@20
    test eax, eax
    jz error

    ; Go back to given directory
    mov esi, dir_path
    push esi
    call _SetCurrentDirectoryA@4
    test eax, eax
    jz error

    ; allocate memory for encoded content
    push READ_BUFFER_SIZE
    push 0x00000008 ; HEAP_ZERO_MEMORY
    push dword [process_heap]
    call _HeapAlloc@12
    test eax, eax
    je error
    mov [encoded_ptr], eax

    mov [mode], byte 1
    call list_files

    ; Close compressed file
    push dword [compressed_handle]
    call _CloseHandle@4
    test eax, eax
    je error

    mov esi, start_path
    push esi
    call _SetCurrentDirectoryA@4
    test eax, eax
    jz error

    ; free memory
    push dword [encoded_ptr]
    push 0
    push dword [process_heap]
    call _HeapFree@12
    test eax, eax
    je error

    ; Free the tree memory
    push dword [tree_ptr]
    push 0
    push dword [process_heap]
    call _HeapFree@12
    test eax, eax
    je error

    ; Exit the program
    push 0
    call _ExitProcess@4

; Recursively lists files in the current directory
list_files:
    push ebp
    mov ebp, esp

    push pwd
    push MAX_PATH
    call _GetCurrentDirectoryA@8

    ; open directory for searching
    push find_data
    push current_dir
    call _FindFirstFileA@8
    cmp eax, -1
    je error
    mov ebx, eax

.process_entry:
    ; check if the entry is "." or ".."
    lea edx, [find_data + 44]
    mov eax, [edx]
    cmp ax, 0x002E
    je .skip_entry
    and eax, 0x00FFFFFF
    cmp eax, 0x002E2E
    je .skip_entry

    ; check if it is a directory
    mov eax, [find_data]
    cmp eax, 0x10
    je .directory

    push 0
    push fullname
    push MAX_PATH
    push find_data + 44
    call _GetFullPathNameA@16
    test eax, eax
    jz error

    cmp [mode], byte 0
    je .dont_write
    ; write path and filename into compressed file
    mov esi, fullname
    call StrLen
    mov [length], eax

    push 0
    push bytes_written
    push dword 4 ; length
    push length
    push dword [compressed_handle]
    call _WriteFile@20
    test eax, eax
    jz error

    push 0
    push bytes_written
    push dword [length] ; length
    push fullname
    push dword [compressed_handle]
    call _WriteFile@20
    test eax, eax
    jz error

.dont_write:
    push ebx
    mov ebp, esp
    call read_file
    mov esp, ebp
    pop ebx

.skip_entry:
    ; find next file
    push find_data
    push ebx
    call _FindNextFileA@8
    test eax, eax
    jnz .process_entry

    ; close search handle no more files
    push ebx
    call _FindClose@4
    test eax, eax
    jz error
    
    pop ebp
    ret

.directory:
    ; change to subdirectory
    lea eax, [find_data + 44]
    push eax
    call _SetCurrentDirectoryA@4
    test eax, eax
    jz error
    mov eax, ebx
    push ebx
    ; recursive call
    call list_files

    ; change back to parent directory
    pop ebx
    push parent_dir
    call _SetCurrentDirectoryA@4
    mov eax, [find_data]
    jmp .skip_entry

read_file:
    ; open file
    push 0
    push 128 ; FILE_ATTRIBUTE_NORMAL
    push 3 ; OPEN_EXISTING
    push 0
    push 0
    push 0x80000000 ; GENERIC_READ
    push fullname ; filename
    call _CreateFileA@28
    cmp eax, -1
    je error
    mov [file_handle], eax

    ; allocate memory for file content
    push READ_BUFFER_SIZE
    push 0x00000008 ; HEAP_ZERO_MEMORY
    push dword [process_heap]
    call _HeapAlloc@12
    test eax, eax
    je error
    mov [mem_ptr], eax

    push 0
    push bytes_read
    push READ_BUFFER_SIZE - 1
    push dword [mem_ptr]
    push dword [file_handle]
    call _ReadFile@20
    test eax, eax
    je error

    ; null terminate the chunk of string
    mov ebx, [bytes_read]
    mov [total_chars], ebx
    add ebx, [mem_ptr]
    mov byte [ebx], 0


    cmp [mode], byte 0
    je .dont_write

    ; copy into heap the encoded text byte by byte
    mov [length], dword 0
    mov eax, [encoded_ptr]
    mov esi, [mem_ptr]

    push ebp
    mov ebp, esp
    xor edi, edi
    mov ecx, 8
    jmp .next
.char_done:
    cmp esp, ebp  ; Check if stack pointer reached the base
    jae .next
    shl edi, 1
    pop ebx
    or edi, ebx
    loop .char_done
    jmp .write

.next:
    movzx edx, byte [esi]
    cmp [bytes_read], dword 0
    je .to_file
    dec dword [bytes_read]
    inc esi

    imul edx, 16
    add edx, [tree_ptr]
.up:
    ; ebx - parent
    ; edx - child
    mov ebx, [edx + 4]
    ; check if at root node
    test ebx, ebx
    jz .char_done

    cmp edx, [ebx + 8]
    je .left
    push dword 1
    mov edx, ebx
    jmp .up

.left:
    push dword 0
    mov edx, ebx
    jmp .up

.write:
    mov [eax], edi
    inc dword [length]
    inc eax
    mov ecx, dword 8
    jmp .up

.to_file:
    shl edi, cl
    mov [eax], edi
    inc dword [length]

    ; length in bytes
    push 0
    push bytes_written
    push dword 4 ; length
    push length
    push dword [compressed_handle]
    call _WriteFile@20
    test eax, eax
    jz error

    ; char count
    push 0
    push bytes_written
    push dword 4 ; length
    push total_chars
    push dword [compressed_handle]
    call _WriteFile@20
    test eax, eax
    jz error

    push 0
    push bytes_written
    push dword [length] ; length
    push dword [encoded_ptr]
    push dword [compressed_handle]
    call _WriteFile@20
    test eax, eax
    jz error
    leave
    jmp .dont_count

.dont_write:
    mov eax, [mem_ptr]
    mov ecx, [bytes_read]
    call count_chars

.dont_count:
    ; close file handle
    push dword [file_handle]
    call _CloseHandle@4
    test eax, eax
    je error
    
    ; free the memory
    push dword [mem_ptr]
    push 0
    push dword [process_heap]
    call _HeapFree@12
    test eax, eax
    je error

    jmp end

count_chars:
    movzx ebx, byte [eax]
    inc dword [freq_table + ebx * 4]
    inc eax
    loop count_chars
    jmp end

print_table:
    xor ecx, ecx
.print_loop:
    mov eax, [freq_table + ecx * 4]
    test eax, eax
    jz .skip
    inc byte [n]
    mov eax, ecx
    call io_writeint
    mov eax, tab
    call io_writestr
    mov [char], cl
    mov eax, char
    call io_writestr
    mov eax, tab
    call io_writestr
    mov eax, [freq_table + ecx * 4]
    call io_writeint
    call io_writeln
.skip:
    inc ecx
    cmp ecx, ALPHABET
    jl .print_loop
    jmp end

build_tree:
    ; allocate memory for the tree
    ; maximum 2 * ALPHABET nodes in total

    ; count   4 byte
    ; parent  4 byte
    ; left    4 byte
    ; right   4 byte

    ; total: 16 byte

    push ALPHABET*2*16
    push 0x00000008 ; HEAP_ZERO_MEMORY
    push dword [process_heap]
    call _HeapAlloc@12
    test eax, eax
    je error
    mov [tree_ptr], eax
    
    ; copy over frequency table
    xor ecx, ecx
    mov ebx, [tree_ptr]
.copy:
    mov eax, [freq_table + ecx * 4]
    mov [ebx], eax
    add ebx, 16
    inc ecx
    
    cmp ecx, ALPHABET
    jl .copy

    mov esi, [tree_ptr]
    add esi, ALPHABET*16

.build:
    ; create new node
    ; find 2 smallest, set their count to 0
    call min
    mov edx, ebx
    mov [edi+4], esi ; child points to parent 
    mov [esi+8], edi ; left child points to min
    mov [edi], dword 0
    call min
    add edx, ebx
    mov [edi+4], esi ; child points to parent 
    mov [esi+12], edi ; right child points to min2
    mov [edi], dword 0
    mov [esi], edx ; sum
    
    mov [tree_root], esi
    cmp eax, 1
    je end
    add esi, 16
    jmp .build

min:
    push ecx
    push edx
    xor eax, eax ; number of elements
    xor ecx, ecx
    mov ebx, 0x7FFFFFFF ; min
    xor edi, edi ; min address
    mov edx, [tree_ptr]
.min_loop:
    cmp [edx], dword 0
    je .skip

    inc eax
    cmp [edx], ebx
    jg .skip
    mov ebx, [edx]
    mov edi, edx

.skip:
    add edx, 16
    inc ecx
    cmp ecx, ALPHABET*2
    jl .min_loop
    pop edx
    pop ecx
    ret

print_code:
    xor ecx, ecx
    push ebp
    mov ebp, esp
.print_loop:
    mov ebx, ecx
    imul ebx, 16
    add ebx, [tree_ptr]
    mov ebx, [ebx + 4]
    test ebx, ebx
    jz .next

    call io_writeln
    mov edx, ecx
    mov [char], dl
    mov eax, char
    call io_writestr
    mov eax, tab
    call io_writestr

    imul edx, 16
    add edx, [tree_ptr]

.up:
    ; ebx - parent
    ; edx - child
    mov ebx, [edx + 4]
    test ebx, ebx ; root has no parent
    jz .next

    cmp edx, [ebx + 8]
    je .left
    push dword 1
    mov edx, ebx
    jmp .up 

.left:
    push dword 0
    mov edx, ebx
    jmp .up

.next:
    cmp esp, ebp  ; Check if stack pointer reached the base
    jae .done
    pop eax       ; Remove one element
    call io_writeint
    jmp .next
.done:
    inc ecx
    cmp ecx, ALPHABET
    jl .print_loop
    call io_writeln
    leave
    jmp end

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