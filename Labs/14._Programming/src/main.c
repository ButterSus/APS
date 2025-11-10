#include "peripheral.h"
#include "platform.h"
#include <stdbool.h>

void setup();
void loop();

void tx_write(const char *str) {
  while (*str) {
    tx_ptr->data = (uint32_t)(*str);
    while (tx_ptr->busy);
    str++;
  }
}

static inline void write_mie(uint32_t value) {
  __asm__ volatile("csrw mie, %0" : : "r"(value));
}

void int_handler(int mcause) {
  if (mcause == MCAUSE(UART_RX_INT_IDX)) {
    static char str [2] = { 0, 0 };
    str [0] = rx_ptr -> data;
    tx_write(str);
  }
  else {
    tx_write("Exception code shown on HEX display\n");
    hex_ptr -> hex0 = (mcause >>  0) & 0xF;
    hex_ptr -> hex1 = (mcause >>  4) & 0xF;
    hex_ptr -> hex2 = (mcause >>  8) & 0xF;
    hex_ptr -> hex3 = (mcause >> 12) & 0xF;
    hex_ptr -> hex4 = (mcause >> 16) & 0xF;
    hex_ptr -> hex5 = (mcause >> 20) & 0xF;
    hex_ptr -> hex6 = (mcause >> 24) & 0xF;
    hex_ptr -> hex7 = (mcause >> 28) & 0xF;
  }
}

int main() {
  setup();
  while (true) {
    loop();
  }
  return 0;
};

void setup() {
  // Set interrupts mask
  write_mie(1 << (0x10 + UART_RX_INT_IDX) |
            1 << (0x10 + SW_INT_IDX) |
            1 << (0x10 + PS2_INT_IDX));

  // Initialize UART
  tx_ptr->baudrate = 115200;
  rx_ptr->baudrate = 115200;
  rx_ptr->parity_bit = 0;
};

void loop() {}
