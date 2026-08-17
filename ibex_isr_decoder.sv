// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module ibex_isr_decoder #(
  parameter bit ISR_ENABLE = 1'b1,
  parameter logic [31:0] ISR_KEY = 32'hA1B2C3D4
) (
  input  logic [31:0] instr_encoded_i,
  output logic [31:0] instr_decoded_o
);

  always_comb begin
    if (ISR_ENABLE) begin
      instr_decoded_o = instr_encoded_i ^ ISR_KEY;
    end else begin
      instr_decoded_o = instr_encoded_i;
    end
  end

endmodule
