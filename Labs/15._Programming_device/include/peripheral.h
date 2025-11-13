#pragma once
#define SW_INT_IDX 1
#define PS2_INT_IDX 3
#define UART_RX_INT_IDX 5
#define TIMER_INT_IDX 8

#define MCAUSE(IDX) (0x80000000 | ((1 << IDX) << 4) & 0x000FFFF0)
