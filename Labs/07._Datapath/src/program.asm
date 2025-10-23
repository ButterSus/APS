# Задача: Написать программу на RV32I, которая реализует алгоритм
# сортировки массива целых чисел (например, сортировка пузырьком
# или вставками) в памяти и выводит отсортированный массив.

# We must follow RVG (RISC-V General-purpose ISA) ABI (Application Binary Interface).
# Also, we must follow GNU Assembly conventions such as default sections.

.text
.global _start
_start:
    la t0, .string
    .rinse_and_repeat:
    lbu t1, (t0)
    mv tp, t1
    addi t0, t0, 1
    bnez t1, .rinse_and_repeat
    ebreak

    # Since we don't have stdout, TX, or any stream output, we'll,
    # instead, put everything to tp (x4 = "Thread pointer"), since
    # it is not in use.

.data
    .string: .asciz "Hello, World!"
