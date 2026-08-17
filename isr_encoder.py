import argparse
import sys

def process_memory_file(input_file, output_file, key_hex, is_decode=False):
    try:
        key = int(key_hex, 16)
    except ValueError:
        print("Loi: Key phai la 1 chuoi hex")
        sys.exit(1)

    key = key & 0xFFFFFFFF
    mode_str = "Giai ma (Decode)" if is_decode else "Ma hoa (Encode)"
    print(f"START {mode_str} file: {input_file}")
    print(f"Khoa (Key): 0x{key:08X}")
    
    # Dựa vào file baseline_test.vmem, vùng code (Instruction) kết thúc và 
    # vùng Data (chuỗi "EXCEPTION!!!", mảng 55,22,99,...) bắt đầu từ word address 0x123.
    # Ta CHỈ mã hóa các địa chỉ < 0x123 để tránh làm hỏng Data.
    MAX_INSTR_ADDR = 0x123 

    try:
        with open(input_file, 'r') as f_in, open(output_file, 'w') as f_out:
            line_count = 0
            current_word_addr = 0
            
            for line in f_in:
                original_line = line.strip()

                if not original_line or original_line.startswith('//') or original_line.startswith('/*'):
                    f_out.write(original_line + '\n')
                    continue

                words = original_line.split()
                if not words:
                    f_out.write('\n')
                    continue

                output_words = []
                for w in words:
                    if w.startswith('@'):
                        output_words.append(w)
                        current_word_addr = int(w[1:], 16)
                    else:
                        try:
                            # Chỉ mã hóa nếu địa chỉ thuộc vùng Instruction
                            if current_word_addr < MAX_INSTR_ADDR:
                                original_instr = int(w, 16)
                                processed_instr = original_instr ^ key
                                output_words.append(f"{processed_instr:08X}")
                                line_count += 1
                            else:
                                # Vùng Data -> Giữ nguyên không mã hóa
                                output_words.append(w)
                                
                            current_word_addr += 1
                        except ValueError:
                            output_words.append(w)
                
                f_out.write(" ".join(output_words) + '\n')
                
        print(f"Thanh cong xu ly (ma hoa) {line_count} lenh (instructions).")
        print(f"Da bo qua phan Data (tu dia chi @{MAX_INSTR_ADDR:08X} tro di).")
        print(f"[+] File ket qua tai: {output_file}\n")

    except FileNotFoundError:
        print(f"Loi khong tim thay file {input_file}")
        sys.exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Tool Ma hoa/Giai ma Instruction Set Randomization (ISR) cho RISC-V")
    parser.add_argument("-i", "--input", required=True, help="File instruction memory input (.vmem, .hex, .bin)")
    parser.add_argument("-o", "--output", required=True, help="File instruction memory output")
    parser.add_argument("-k", "--key", required=True, help="Khoa ma hoa dang Hex 32-bit (VD: DEADBBEEF)")
    parser.add_argument("-d", "--decode", action="store_true", help="Bat che do giai ma nguoc")
    args = parser.parse_args()
    process_memory_file(args.input, args.output, args.key, args.decode)
