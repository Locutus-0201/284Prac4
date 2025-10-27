%include "constants.inc"
global readDfa
extern fopen, fclose, fgets, strtok, atoi, initDfa

section .data
mode db "r", 0
comma db ",", 0

section .text
;
; DFA *readDfa(const char *filename)
; 
; Reads a DFA specification from a file with the following format:
; Line 1: numStates,numTransitions
; Line 2: state IDs
; Line 3: accepting state IDs
; Remaining lines: transitions in format from,to,symbol
;
; Returns: pointer to DFA structure, or NULL on failure
;

readDfa:
  ; Function prologue - save callee-saved registers
  push rbp
  mov rbp, rsp
  push rbx
  push r12
  push r13
  push r14
  push r15
  ; Allocate 512 bytes on stack for line buffer
  sub rsp, 512
  mov rbx, rsp             ; rbx = buffer pointer






  ; STEP 1: Open the file
  ; fopen(filename, "r")
  mov rsi, mode
  call fopen
  test rax, rax
  je .fail_no_file         ; if fopen returns NULL, fail
  mov r12, rax            ; r12 = FILE* (save file pointer)






  ; STEP 2: Read first line - numStates,numTransitions
  ; fgets(buffer, 512, file)
  mov rdi, rbx            ; buffer
  mov esi, 512            ; max size
  mov rdx, r12            ; FILE*
  call fgets
  test rax, rax
  je .fail                ; if fgets fails, cleanup and return NULL

  ; Parse numStates (first token before comma)
  mov rdi, rbx
  mov rsi, comma
  call strtok
  test rax, rax
  je .fail
  mov rdi, rax
  call atoi               ; convert string to integer
  mov r14d, eax           ; r14d = numStates

  ; Parse numTransitions (second token after comma)
  xor edi, edi            ; NULL (continue from previous strtok)
  mov rsi, comma
  call strtok
  test rax, rax
  je .fail
  mov rdi, rax
  call atoi               ; convert string to integer
  mov r15d, eax           ; r15d = numTransitions







  ; STEP 3: Initialize DFA structure
  ; initDfa(numStates, numTransitions)
  mov edi, r14d           ; arg1 = numStates
  mov esi, r15d           ; arg2 = numTransitions
  call initDfa
  test rax, rax
  je .fail                ; if initDfa returns NULL, fail
  mov r13, rax            ; r13 = DFA* (save DFA pointer)






  ; STEP 4: Read second line - state IDs (e.g., "0,1,2")
  mov rdi, rbx
  mov esi, 512
  mov rdx, r12
  call fgets
  test rax, rax
  je .fail

  ; Parse state IDs and populate states array
  mov rdi, rbx
  mov rsi, comma
  call strtok
  test rax, rax
  je .states_parsed_done   ; empty line edge case

  xor r14d, r14d          ; r14d = index i = 0

.states_ids_loop:
  ; Convert token to integer (state ID)
  mov rdi, rax
  call atoi               ; eax = state ID
  
  ; Calculate pointer to states[i]
  ; states[i] = dfa->states + i * sizeof(State)
  mov rcx, [r13 + DFA.states]  ; rcx = base pointer to states array
  mov edx, r14d                ; edx = i
  imul edx, State_size         ; edx = i * sizeof(State)
  add rcx, rdx                 ; rcx = &states[i]
  
  ; Store state.id and initialize state.isAccepting = false
  mov dword [rcx + State.id], eax
  mov byte [rcx + State.isAccepting], 0

  ; Move to next state
  inc r14d
  ; Get next comma-separated token
  xor edi, edi            ; NULL (continue strtok)
  mov rsi, comma
  call strtok
  test rax, rax
  jne .states_ids_loop    ; loop while tokens exist

.states_parsed_done:
  





  ; STEP 5: Read third line - accepting state IDs
  mov rdi, rbx
  mov esi, 512
  mov rdx, r12
  call fgets
  test rax, rax
  je .transitions_start    ; if read fails, skip to transitions

  ; Parse first accepting state ID
  mov rdi, rbx
  mov rsi, comma
  call strtok
  test rax, rax
  je .transitions_start    ; empty line = no accepting states

.accept_loop:
  ; Convert token to integer (accepting state ID)
  mov rdi, rax
  call atoi
  mov r14d, eax           ; r14d = target accepting state ID

  ; Search through states array to find matching ID
  mov rcx, [r13 + DFA.states]  ; rcx = states array base
  xor r15d, r15d               ; r15d = j = 0

.search_states_loop:
  ; Check if we've searched all states
  mov edx, dword [r13 + DFA.numStates]
  cmp r15d, edx
  jge .accept_next_token       ; if j >= numStates, done searching

  ; Calculate pointer to states[j]
  mov edx, r15d
  imul edx, State_size
  lea rsi, [rcx + rdx]         ; rsi = &states[j]
  
  ; Compare states[j].id with target accepting ID
  mov eax, dword [rsi + State.id]
  cmp eax, r14d
  jne .not_match
  
  ; Match found - mark state as accepting
  mov byte [rsi + State.isAccepting], 1
  jmp .accept_next_token

.not_match:
  inc r15d                     ; j++
  jmp .search_states_loop

.accept_next_token:
  ; Get next accepting state ID
  xor edi, edi
  mov rsi, comma
  call strtok
  test rax, rax
  jne .accept_loop            ; loop while tokens exist






  ; STEP 6: Read remaining lines - transitions
.transitions_start:
  xor r14d, r14d              ; r14d = transition index t = 0

.trans_loop_check:
  ; Check if we've read all transitions
  mov edx, dword [r13 + DFA.numTransitions]
  cmp r14d, edx
  jge .done_transitions       ; if t >= numTransitions, done

  ; Read next transition line
  mov rdi, rbx
  mov esi, 512
  mov rdx, r12
  call fgets
  test rax, rax
  je .fail

  ; Parse 'from' state ID (first token)
  mov rdi, rbx
  mov rsi, comma
  call strtok
  test rax, rax
  je .fail
  mov rdi, rax
  call atoi
  mov r15d, eax              ; r15d = from state ID

  ; Parse 'to' state ID (second token)
  xor edi, edi
  mov rsi, comma
  call strtok
  test rax, rax
  je .fail
  mov rdi, rax
  call atoi
  push rax                   ; save 'to' on stack

  ; Parse symbol (third token - single character)
  xor edi, edi
  mov rsi, comma
  call strtok
  test rax, rax
  je .fail
  movzx edx, byte [rax]      ; edx = symbol

  pop rax                    ; restore 'to' state ID
  
  ; Calculate pointer to transitions[t]
  ; transitions[t] = dfa->transitions + t * sizeof(Transition)
  mov rcx, [r13 + DFA.transitions]  ; rcx = transitions array base
  push rax
  mov eax, r14d                     ; eax = t
  imul eax, Transition_size         ; eax = t * sizeof(Transition)
  add rcx, rax                      ; rcx = &transitions[t]
  pop rax
  
  ; Store transition fields
  mov dword [rcx + Transition.from], r15d    ; transitions[t].from
  mov dword [rcx + Transition.to], eax       ; transitions[t].to
  mov byte [rcx + Transition.symbol], dl     ; transitions[t].symbol

  ; Move to next transition
  inc r14d
  jmp .trans_loop_check





  ; STEP 7: Cleanup and return
.done_transitions:
  ; Close file and return DFA pointer
  mov rax, r13               ; rax = DFA* (return value)
  mov rdi, r12               ; rdi = FILE*
  push rax                   ; save return value across fclose
  call fclose
  pop rax                    ; restore return value
  
  ; Function epilogue - restore stack and registers
  add rsp, 512
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  pop rbp
  ret




  ; Error handling
.fail:
  ; Close file before returning NULL
  mov rdi, r12
  call fclose

.fail_no_file:
  ; Return NULL
  xor eax, eax
  ; Restore stack and registers
  add rsp, 512
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbx
  pop rbp
  ret