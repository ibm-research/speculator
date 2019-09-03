# Interesting findings

## Out of order execution

- clflush of a memory location followed by an access of the same location can be
  re-ordered and therefore the value would be accessed through the cache and not
  the main memory as we would expect. Therefore lfence is required to serialize
  and make sure the cache is flushed before accessing the memory location.

  wrong example:
```asm
    clflush [mem]
    mov ebx, [mem]
```
  correct example:
```asm
    clflush [mem]
    lfence
    mov ebx, [mem]
```
- This macro can be used to flush the pipeline (from spectre v4)
- 
```asm
 %macro pipeline_flush 0
        mov rax, 0
        cpuid
        lfence
    %endmacro
```

## FNOP

if you want to have a nop that needs an execution unit (and thus increases the executed count), use `FNOP` - from page 138 in the bible

## ROB

- UOPS_EXECUTED != ROB unit occupied due to fusing and unfusing of uops and also
  internal optimization, e.g. xor eax, eax

- CMP and JE get fused and count as 1 instruction in UOPS_EXECUTED.THREAD/CORE

## CYCLES
- Sometimes cycles counter presents outliers (up to 10X more than the avg value). It
  is not syscall part because test with start/stop only does not present those
  outliers. We found that clflush/load from mem have to synchronize with other cores and
  therefore it has to spend cycles to wait for coherence to be verified. Also
  the operations on the file descriptor may load in the cache also the
  warmup_count due to proximity. To prevent this it is necessary push the two
  variables apart using an array big enough.

## MISC
- UOPS_ISSUED.SiNGLE_MUL only works on haswell and previous machine
- DIV is slower than uncached access
- Example of SlowLea lea rax, [array2] --> UOPS_ISSUED.SLOW_LEA
- start_counter does interesting things to the cache...to make sure that a
  variable is out of the cache...a clflush must be run after start_counter
- ~~loads if uncached are counted as SLOW_LEA!!!~~
- clflush is counted as slow lea not the load of uncached value which was stated the point above
