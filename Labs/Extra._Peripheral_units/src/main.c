#include "peripheral.h"
#include "platform.h"
#include <stdbool.h>
#include <stdint.h>

#define CHARS_CNT 960

void tx_write(const char *str) {
  char c;
  while ((c = *str++) != '\0') {
    while (tx_ptr->busy);
    tx_ptr->data = (uint32_t)(c);
    while (tx_ptr->busy);
  }
}

uint32_t idx = 0;
static uint32_t ascii_map[] = {
  0x00000000, 0x00000000, 0x00000000, 0x007E0900, 0x00000000, 0x00317100,
  0x737A0000, 0x00327761, 0x64786300, 0x00333465, 0x66762000, 0x00357274,
  0x68626E00, 0x00367967, 0x6A6D0000, 0x00383775, 0x696B2C00, 0x0039306F,
  0x6C2F2E00, 0x002D703B, 0x00270000, 0x00003D5B, 0x5D0D0000
};

int cnt = 0;
int iteration = 0;

void itoa_hex(unsigned int num, char *buf) {
  static const char hex_chars[] = "0123456789ABCDEF";
  char temp[9];  // 8 hex digits + null terminator
  int i;

  temp[8] = '\0';
  for (i = 7; i >= 0; i--) {
    temp[i] = hex_chars[num & 0xF];
    num >>= 4;
  }

  // Find first non-zero digit
  for (i = 0; i < 8 && temp[i] == '0'; i++);

  if (i == 8) {
    // The number is 0
    buf[0] = '0';
    buf[1] = '\0';
  } else {
    // Copy from first non-zero digit
    int j = 0;
    while (temp[i] != '\0') {
        buf[j++] = temp[i++];
    }
    buf[j] = '\0';
  }
}

void int_handler(int mcause) {
  uint32_t scancode = ps2_ptr->scan_code;
  if (scancode >= sizeof(ascii_map) * 4)
    return;

  char ascii_code = ((uint8_t *)ascii_map)[scancode];
  if (vga.tiff_map[ascii_code * 16 + 7] == 0b00111111) {
    tx_write("Got empty symbol\n");
    return;
  }

  vga.char_map[idx] = ascii_code;
  char buf [9];
  itoa_hex(scancode, buf);
  tx_write("1. Scancode: 0x");
  tx_write(buf);
  tx_write("\n");
  itoa_hex(ascii_code, buf);
  tx_write("2. ASCII-code: 0x");
  tx_write(buf);
  tx_write("\n");
  itoa_hex(vga.tiff_map[ascii_code * 16 + 8], buf);
  tx_write("3. TIFF-map: 0x");
  tx_write(buf);
  tx_write("\n");
  idx = idx >= CHARS_CNT - 1 ? 0 : idx + 1;
}

int main() {
  // Enable PS2 interrupts only
  __asm__ volatile("csrw mie, %0" : : "r"(1 << (0x10 + PS2_INT_IDX)));
  tx_ptr->baudrate = 115200;

  // Waiting if switch [0] is ON.
  led_ptr->value |= (1 << 0);
  while (((sw_ptr->value) & (1 << 0)) != 0);
  led_ptr->value &= ~(1 << 0);

  tx_write("Initialized successfully\n");

  while (true) {
    if (cnt >= 1000000) {
      // tx_write("Waiting, iteration=");
      // static char iteration_str [9];
      // itoa_hex(iteration, iteration_str);
      // tx_write(iteration_str);
      // tx_write("\n");
      cnt = 0;
      iteration++;
    }
    cnt ++;
  }
};
