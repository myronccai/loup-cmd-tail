# Tasks: tail

- [x] 1. Parse counts with `+`/`-` and suffixes, and seconds for `-s`
  - _Requirements: 2.1, 4.2_
- [x] 2. Parse options: short groups with arguments, long options with prefixes and `--follow[=HOW]`, the obsolete `-N`/`+N` form, usage errors
  - _Requirements: 2.2, 2.3, 5.1, 5.2, 5.4_
- [x] 3. Select the last lines or lines from N (`-n`, `-z`) byte for byte
  - _Requirements: 1.1, 1.2, 1.4, 1.5_
- [x] 4. Select the last bytes or bytes from N (`-c`) and print them exactly
  - _Requirements: 1.3, 1.4_
- [x] 5. Headers and per-operand errors
  - _Requirements: 3.1, 3.2, 5.3_
- [x] 6. Follow mode: polling loop, headers on switch, truncation, pipes, no files remaining
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_
- [x] 7. Unit tests and end-to-end tests of the native binary, including `-f`
  - _Requirements: all_
