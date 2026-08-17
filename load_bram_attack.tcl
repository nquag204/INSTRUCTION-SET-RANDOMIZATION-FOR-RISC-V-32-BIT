if { ![info exists vmem_file] } {
    set vmem_file "baseline_simple_100000.vmem"
}

puts "\n========================================="
puts "  MO PHONG TAN CONG (HACKER NAP CODE THO)  "
puts "=========================================\n"

puts "Preparing JTAG-to-AXI interface..."
set hw_axi [get_hw_axis hw_axi_1]
if { [llength $hw_axi] == 0 } {
    puts "ERROR: hw_axi_1 not found! Please check your Hardware Manager connection."
    return
}

puts "Reading file $vmem_file ..."
set fp [open $vmem_file r]
set current_jtag_addr 0xB0000080
set count 0

while { [gets $fp line] >= 0 } {
    set line [string trim $line]
    if { $line eq "" || [string match "//*" $line] } { continue }
    
    if { [string match "@*" $line] } {
        continue
    }
    
    foreach word_hex [split $line " "] {
        if { $word_hex ne "" } {
            set addr [format "0x%08X" $current_jtag_addr]
            
            # HACKER NẠP CODE THÔ (KHÔNG MÃ HÓA)
            set raw_hex $word_hex
            
            # Ghi vào BRAM
            create_hw_axi_txn -address $addr -data $raw_hex -type write -force wr_txn $hw_axi
            run_hw_axi wr_txn
            
            set current_jtag_addr [expr { $current_jtag_addr + 4 }]
            set count [expr { $count + 1 }]
            
            if { $count >= 2000 } {
                break
            }
        }
    }
    if { $count >= 2000 } {
        break
    }
}
close $fp
puts "HACKER DA NAP XONG CODE DOC HAI (CHUA MA HOA) VAO BRAM!"
