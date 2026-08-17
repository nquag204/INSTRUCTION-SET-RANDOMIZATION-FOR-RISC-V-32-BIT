if { ![info exists vmem_file] } {
    set vmem_file "baseline_simple_100000.vmem"
}

puts "Preparing JTAG-to-AXI interface..."
set hw_axi [get_hw_axis hw_axi_1]
if { [llength $hw_axi] == 0 } {
    puts "ERROR: hw_axi_1 not found! Please check your Hardware Manager connection."
    return
}

puts "Reading file $vmem_file ..."
set fp [open $vmem_file r]

# CPU boots at 0x000FE080.
# BRAM is mapped at 0xB0000000 for JTAG, which corresponds to 0x000FE000 for CPU.
# So CPU boot address 0x000FE080 = JTAG address 0xB0000080.
set current_jtag_addr 0xB0000080
set encryption_key 0xA1B2C3D4
set count 0

while { [gets $fp line] >= 0 } {
    set line [string trim $line]
    if { $line eq "" || [string match "//*" $line] } { continue }
    
    # Bỏ qua dòng địa chỉ (VD: @00100000) vì file biên dịch sai địa chỉ so với phần cứng
    if { [string match "@*" $line] } {
        puts "Ignoring address directive: $line, forcing write to CPU Boot Address 0x000FE080"
        continue
    }
    
    foreach word_hex [split $line " "] {
        if { $word_hex ne "" } {
            set addr [format "0x%08X" $current_jtag_addr]
            
            # Giải mã Hex string
            scan $word_hex "%x" data_int
            
            # Mã hóa lệnh bằng XOR
            set encrypted_int [expr { ($data_int ^ $encryption_key) & 0xFFFFFFFF }]
            set encrypted_hex [format "%08X" $encrypted_int]
            
            # Ghi vào BRAM
            create_hw_axi_txn -address $addr -data $encrypted_hex -type write -force wr_txn $hw_axi
            run_hw_axi wr_txn
            
            set current_jtag_addr [expr { $current_jtag_addr + 4 }]
            set count [expr { $count + 1 }]
            
            # Ngăn không cho ghi quá giới hạn 8KB của BRAM
            if { $count >= 2000 } {
                break
            }
        }
    }
    if { $count >= 2000 } {
        puts "Reached 8KB BRAM limit, stopping."
        break
    }
}
close $fp
puts "Successfully loaded $count encrypted instructions into BRAM starting at boot address!"
