#ifdef PROJECT_0
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
#endif

#include "peripheral.h"
#include "platform.h"
#include <stdbool.h>

#define STACK_SIZE 5

static uint32_t stack[STACK_SIZE];
static int32_t top = -1;

static inline int stack_push(uint32_t value) {
  if (top >= STACK_SIZE - 1) {
    return -1; // stack overflow
  }
  stack[++top] = value;
  return 0;
}

static inline int stack_pop(uint32_t *value) {
  if (top < 0) {
    return -1; // stack underflow
  }
  *value = stack[top--];
  return 0;
}

static inline int stack_is_empty() {
  return top == -1;
}

static inline int stack_is_full() {
  return top == STACK_SIZE - 1;
}

void tx_write(const char *str) {
  char c;
  while ((c = *str++) != '\0') {
    // Make sure no other operation is being done
    while (tx_ptr->busy);
    tx_ptr->data = (uint32_t)(c);
  }
}

void tx_write_bin(uint32_t num) {
  static char buffer[35] = "0b--------------------------------";
  for (int i = 0; i < 32; i++) {
    // Extract bit from MSB to LSB and convert to '0' or '1'
    buffer[2 + i] = (num & (1U << (31 - i))) ? '1' : '0';
  }
  tx_write(buffer);
}

void int_handler(int mcause) {
  if (mcause == MCAUSE(PS2_INT_IDX)) {
    uint32_t scancode = ps2_ptr -> scan_code;
    stack_push(scancode);
  }
  // else {
  //   tx_write("Unexpected interrupt, see code on hex display.\n");
  //   hex_ptr -> hex0 = (mcause >>  0) & 0xF;
  //   hex_ptr -> hex1 = (mcause >>  4) & 0xF;
  //   hex_ptr -> hex2 = (mcause >>  8) & 0xF;
  //   hex_ptr -> hex3 = (mcause >> 12) & 0xF;
  //   hex_ptr -> hex4 = (mcause >> 16) & 0xF;
  //   hex_ptr -> hex5 = (mcause >> 20) & 0xF;
  //   hex_ptr -> hex6 = (mcause >> 24) & 0xF;
  //   hex_ptr -> hex7 = (mcause >> 28) & 0xF;
  // }
}

int main() {
  // Enable PS2 interrupts only
  __asm__ volatile("csrw mie, %0" : : "r"(1 << (0x10 + PS2_INT_IDX)));
  tx_ptr->baudrate = 115200;
  tx_write("Initialized successfully");
  while (true) {
    if (stack_is_empty()) continue;
    uint32_t scancode;
    stack_pop(&scancode);
    tx_write("Got scancode: ");
    tx_write_bin(scancode);
    tx_write("\n");
  };
};
