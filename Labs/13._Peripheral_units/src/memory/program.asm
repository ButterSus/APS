# Задача: Написать программу на RV32I, которая реализует алгоритм
# сортировки массива целых чисел (например, сортировка пузырьком
# или вставками) в памяти и выводит отсортированный массив.

# Inspired by: https: //marz.utk.edu/my-courses/cosc230/book/example-risc-v-assembly-programs/

    .section .text
    .global  _start
_start:
    la       sp, _stack_ptr

# No need to save caller's variables, we're not inside of
# function, we're inside of entry point of whole program
    la       a0, array
    li       a1, 4
    call     sort_array

    la       t0, array
    lbu      s0, 0(t0)
    lbu      s1, 1(t0)
    lbu      s2, 2(t0)
    lbu      s3, 3(t0)

    ebreak

sort_array: # Ah, my classic bubble sort from C
# a0 = int a[]
# a1 = int size

# t0 = i
# t1 = j
# t2 = size_i
# t3 = a + 4j
# t4 = a [j]
# t5 = a [j + 1]

    li       t0, 0           # i = 0
1: # for (int i = 0; i < size; i ++) {
    bge      t0, a1, 1f      # if (i >= size) break;

    addi     t2, a1, -1      # size_i = size - 1
    sub      t2, t2, t0      # size_i -= i

    li       t1, 0           # j = 0
2: # for (int j = 0; j < size - i - 1; j ++) {
    bge      t1, t2, 2f      # if (j >= size - i - 1)

    add      t3, t1, a0
    lbu      t4, 0(t3)
    lbu      t5, 1(t3)
3: # if (arr[j] > arr[j + 1]) {
    ble      t4, t5, 3f      # if (arr[j] <= arr[j + 1]) break;

    sb       t4, 1(t3)  # Swap elements directly in memory
    sb       t5, 0(t3)  # So no need in temporaries

3: # }

    addi     t1, t1, 1
    j        2b
2: # }

    addi     t0, t0, 1
    j        1b
1: # }
    ret

    .section .data
array:
    .byte    10, 30, 20, 40
