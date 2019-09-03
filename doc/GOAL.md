# Speculator Goal

1. How much can be speculated give
    * reorder buffer size on arch   -  *DONE*
    * memory access required in the control flow condition
    * page fault occurring
    * type of cmp/jump instruction
    * instructions that are in the speculation sled

2. Put a syscall in the part that is speculated (or "speculation stoppers")
   (e.g. lfence?)  -  *DONE*

3. How can we be certain that it is speculated
    * jnz vs jz
    * spectre-like check (store in speculated part + timing of memory access
      after)
    * time the execution of the snippet - after learning it should be faster

4. Speculation within speculation - *DONE*

5. Interactions in hyperthreded cores

6. RDPMC during a speculation + spectre-like attack

7. Verifying retpoline behaviour  -  *DONE*

8. Test read-after-write as spectre v4  -  *DONE*

9. Clflush bahaviour in speculation  -  *DONE*

10. Failed store-forward as delimiter for speculation - *DONE*

11. 2e/3e prefix bytes can be insert in jcc instructions to statically hint
    taken or not taken

12. maybe a small experiment that explores a speculative branch with a variable
nopsled + a slow lea and checking the counters is already good enough

nopsled + slow_lea / single_mul instead of the mov - that should do the trick
and then we can check if executed is correlated with issued  *DONE*

13. can you do: [spec. start] FNOP FNOP...FNOP (with increasing number of FNOPs
    and looking at the executed count) *DONE*

14. checking whether MPX bounds checks serialize or not
