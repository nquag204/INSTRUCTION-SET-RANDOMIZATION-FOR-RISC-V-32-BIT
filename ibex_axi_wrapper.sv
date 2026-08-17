// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// =============================================================================
// ibex_axi_wrapper.sv  (Simplified for Vivado IP Packager)
// =============================================================================
// AXI4-Lite Master Wrapper for Ibex RISC-V Core (with ISR support).
//
// ALL complex SystemVerilog parameters (enums, packages) are hardcoded inside
// this module to avoid Vivado IP Packager compatibility issues.
//
// Architecture:
//   - M_AXI_INSTR: Read-only  AXI4-Lite Master for instruction fetch
//   - M_AXI_DATA:  Read/Write AXI4-Lite Master for data load/store
// =============================================================================

module ibex_axi_wrapper #(
  parameter integer ADDR_WIDTH = 32,
  parameter integer DATA_WIDTH = 32,
  parameter integer BOOT_ADDR  = 32'h00100000
) (
  // =========================================================================
  // Clock and Reset
  // =========================================================================
  input  wire                      clk_i,
  input  wire                      rst_ni,

  // =========================================================================
  // AXI4-Lite Master Interface: Instruction Fetch (Read-Only)
  // =========================================================================
  output wire [ADDR_WIDTH-1:0]     m_axi_instr_araddr,
  output wire [2:0]                m_axi_instr_arprot,
  output wire                      m_axi_instr_arvalid,
  input  wire                      m_axi_instr_arready,
  input  wire [DATA_WIDTH-1:0]     m_axi_instr_rdata,
  input  wire [1:0]                m_axi_instr_rresp,
  input  wire                      m_axi_instr_rvalid,
  output wire                      m_axi_instr_rready,
  output wire [ADDR_WIDTH-1:0]     m_axi_instr_awaddr,
  output wire [2:0]                m_axi_instr_awprot,
  output wire                      m_axi_instr_awvalid,
  input  wire                      m_axi_instr_awready,
  output wire [DATA_WIDTH-1:0]     m_axi_instr_wdata,
  output wire [3:0]                m_axi_instr_wstrb,
  output wire                      m_axi_instr_wvalid,
  input  wire                      m_axi_instr_wready,
  input  wire [1:0]                m_axi_instr_bresp,
  input  wire                      m_axi_instr_bvalid,
  output wire                      m_axi_instr_bready,

  // =========================================================================
  // AXI4-Lite Master Interface: Data Load/Store (Read/Write)
  // =========================================================================
  output wire [ADDR_WIDTH-1:0]     m_axi_data_araddr,
  output wire [2:0]                m_axi_data_arprot,
  output wire                      m_axi_data_arvalid,
  input  wire                      m_axi_data_arready,
  input  wire [DATA_WIDTH-1:0]     m_axi_data_rdata,
  input  wire [1:0]                m_axi_data_rresp,
  input  wire                      m_axi_data_rvalid,
  output wire                      m_axi_data_rready,
  output wire [ADDR_WIDTH-1:0]     m_axi_data_awaddr,
  output wire [2:0]                m_axi_data_awprot,
  output wire                      m_axi_data_awvalid,
  input  wire                      m_axi_data_awready,
  output wire [DATA_WIDTH-1:0]     m_axi_data_wdata,
  output wire [3:0]                m_axi_data_wstrb,
  output wire                      m_axi_data_wvalid,
  input  wire                      m_axi_data_wready,
  input  wire [1:0]                m_axi_data_bresp,
  input  wire                      m_axi_data_bvalid,
  output wire                      m_axi_data_bready,

  // =========================================================================
  // Interrupt Inputs
  // =========================================================================
  input  wire                      irq_software_i,
  input  wire                      irq_timer_i,
  input  wire                      irq_external_i,
  input  wire [14:0]               irq_fast_i,
  input  wire                      irq_nm_i,

  // =========================================================================
  // Debug & Control
  // =========================================================================
  input  wire                      debug_req_i,
  input  wire [31:0]               hart_id_i,
  output wire                      core_sleep_o
);

  // Import Ibex types internally (not exposed to IP Packager)
  import ibex_pkg::*;

  // ===========================================================================
  // Internal signals: Ibex OBI-like memory interface
  // ===========================================================================
  logic        instr_req;
  logic        instr_gnt;
  logic        instr_rvalid;
  logic [31:0] instr_addr;
  logic [31:0] instr_rdata;
  logic        instr_err;

  logic        data_req;
  logic        data_gnt;
  logic        data_rvalid;
  logic        data_we;
  logic [3:0]  data_be;
  logic [31:0] data_addr;
  logic [31:0] data_wdata;
  logic [31:0] data_rdata;
  logic        data_err;

  // ===========================================================================
  // Ibex Core Instantiation (all parameters hardcoded)
  // ===========================================================================
  ibex_top #(
    .PMPEnable        ( 1'b0                          ),
    .PMPNumRegions    ( 4                             ),
    .MHPMCounterNum   ( 0                             ),
    .MHPMCounterWidth ( 40                            ),
    .RV32E            ( 1'b0                          ),
    .RV32M            ( ibex_pkg::RV32MFast           ),
    .RV32B            ( ibex_pkg::RV32BNone           ),
    .BranchTargetALU  ( 1'b0                          ),
    .WritebackStage   ( 1'b0                          ),
    .ICache           ( 1'b0                          ),
    .ICacheECC        ( 1'b0                          ),
    .DbgTriggerEn     ( 1'b0                          ),
    .SecureIbex       ( 1'b0                          ),
    .ICacheScramble   ( 1'b0                          ),
    .BranchPredictor  ( 1'b0                          ),
    .DmHaltAddr       ( 32'h1A110800                  ),
    .DmExceptionAddr  ( 32'h1A110808                  )
  ) u_ibex_top (
    .clk_i                    ( clk_i                          ),
    .rst_ni                   ( rst_ni                         ),

    .test_en_i                ( 1'b0                           ),
    .ram_cfg_icache_tag_i     ( '{default: '0}                 ),
    .ram_cfg_icache_tag_o     (                                ),
    .ram_cfg_icache_data_i    ( '{default: '0}                 ),
    .ram_cfg_icache_data_o    (                                ),

    .hart_id_i                ( hart_id_i                      ),
    .boot_addr_i              ( BOOT_ADDR[31:0]                ),

    // Instruction memory interface
    .instr_req_o              ( instr_req                      ),
    .instr_gnt_i              ( instr_gnt                      ),
    .instr_rvalid_i           ( instr_rvalid                   ),
    .instr_addr_o             ( instr_addr                     ),
    .instr_rdata_i            ( instr_rdata                    ),
    .instr_rdata_intg_i       ( 7'b0                           ),
    .instr_err_i              ( instr_err                      ),

    // Data memory interface
    .data_req_o               ( data_req                       ),
    .data_gnt_i               ( data_gnt                       ),
    .data_rvalid_i            ( data_rvalid                    ),
    .data_we_o                ( data_we                        ),
    .data_be_o                ( data_be                        ),
    .data_addr_o              ( data_addr                      ),
    .data_wdata_o             ( data_wdata                     ),
    .data_wdata_intg_o        (                                ),
    .data_rdata_i             ( data_rdata                     ),
    .data_rdata_intg_i        ( 7'b0                           ),
    .data_err_i               ( data_err                       ),

    // Interrupts
    .irq_software_i           ( irq_software_i                 ),
    .irq_timer_i              ( irq_timer_i                    ),
    .irq_external_i           ( irq_external_i                 ),
    .irq_fast_i               ( irq_fast_i                     ),
    .irq_nm_i                 ( irq_nm_i                       ),

    // Scrambling (unused)
    .scramble_key_valid_i     ( 1'b0                           ),
    .scramble_key_i           ( '0                             ),
    .scramble_nonce_i         ( '0                             ),
    .scramble_req_o           (                                ),

    // Debug
    .debug_req_i              ( debug_req_i                    ),
    .crash_dump_o             (                                ),
    .double_fault_seen_o      (                                ),

    // CPU Control
    .fetch_enable_i           ( ibex_pkg::IbexMuBiOn           ),
    .mcounteren_writable_i    ( ibex_pkg::IbexMuBiOn           ),
    .alert_minor_o            (                                ),
    .alert_major_internal_o   (                                ),
    .alert_major_bus_o        (                                ),
    .core_sleep_o             ( core_sleep_o                   ),

    .scan_rst_ni              ( 1'b1                           ),
    .lockstep_cmp_en_o        (                                ),

    // Shadow outputs (unused)
    .data_req_shadow_o        (                                ),
    .data_we_shadow_o         (                                ),
    .data_be_shadow_o         (                                ),
    .data_addr_shadow_o       (                                ),
    .data_wdata_shadow_o      (                                ),
    .data_wdata_intg_shadow_o (                                ),
    .instr_req_shadow_o       (                                ),
    .instr_addr_shadow_o      (                                )
  );

  // ===========================================================================
  // OBI-to-AXI4-Lite Bridge: Instruction Fetch (Read-Only)
  // ===========================================================================

  // Tie off write channels
  assign m_axi_instr_awaddr  = {ADDR_WIDTH{1'b0}};
  assign m_axi_instr_awprot  = 3'b0;
  assign m_axi_instr_awvalid = 1'b0;
  assign m_axi_instr_wdata   = {DATA_WIDTH{1'b0}};
  assign m_axi_instr_wstrb   = 4'b0;
  assign m_axi_instr_wvalid  = 1'b0;
  assign m_axi_instr_bready  = 1'b1;

  assign m_axi_instr_arprot  = 3'b100;

  // Instruction FSM
  reg [1:0] instr_state;
  localparam INSTR_IDLE     = 2'd0;
  localparam INSTR_AR_PHASE = 2'd1;
  localparam INSTR_R_PHASE  = 2'd2;

  reg [31:0] instr_addr_r;

  // Instruction FSM outputs (active-low reset compatible with reg)
  reg        instr_gnt_r;
  reg        instr_rvalid_r;
  reg [31:0] instr_rdata_r;
  reg        instr_err_r;
  reg [31:0] instr_araddr_r;
  reg        instr_arvalid_r;
  reg        instr_rready_r;

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      instr_state  <= INSTR_IDLE;
      instr_addr_r <= 32'b0;
    end else begin
      if (instr_req && (instr_state == INSTR_IDLE))
        instr_addr_r <= instr_addr;

      case (instr_state)
        INSTR_IDLE: begin
          if (instr_req) begin
            if (m_axi_instr_arready)
              instr_state <= INSTR_R_PHASE;
            else
              instr_state <= INSTR_AR_PHASE;
          end
        end
        INSTR_AR_PHASE: begin
          if (m_axi_instr_arready)
            instr_state <= INSTR_R_PHASE;
        end
        INSTR_R_PHASE: begin
          if (m_axi_instr_rvalid)
            instr_state <= INSTR_IDLE;
        end
        default: instr_state <= INSTR_IDLE;
      endcase
    end
  end

  // Combinational outputs for instruction bridge
  always @(*) begin
    instr_gnt_r     = 1'b0;
    instr_rvalid_r  = 1'b0;
    instr_rdata_r   = 32'b0;
    instr_err_r     = 1'b0;
    instr_araddr_r  = instr_addr_r;
    instr_arvalid_r = 1'b0;
    instr_rready_r  = 1'b0;

    case (instr_state)
      INSTR_IDLE: begin
        if (instr_req) begin
          instr_araddr_r  = instr_addr;
          instr_arvalid_r = 1'b1;
          if (m_axi_instr_arready)
            instr_gnt_r = 1'b1;
        end
      end
      INSTR_AR_PHASE: begin
        instr_arvalid_r = 1'b1;
        if (m_axi_instr_arready)
          instr_gnt_r = 1'b1;
      end
      INSTR_R_PHASE: begin
        instr_rready_r = 1'b1;
        if (m_axi_instr_rvalid) begin
          instr_rvalid_r = 1'b1;
          instr_rdata_r  = m_axi_instr_rdata;
          instr_err_r    = (m_axi_instr_rresp != 2'b00);
        end
      end
      default: ;
    endcase
  end

  assign instr_gnt    = instr_gnt_r;
  assign instr_rvalid = instr_rvalid_r;
  assign instr_rdata  = instr_rdata_r;
  assign instr_err    = instr_err_r;
  assign m_axi_instr_araddr  = instr_araddr_r;
  assign m_axi_instr_arvalid = instr_arvalid_r;
  assign m_axi_instr_rready  = instr_rready_r;

  // ===========================================================================
  // OBI-to-AXI4-Lite Bridge: Data Load/Store (Read/Write)
  // ===========================================================================

  assign m_axi_data_arprot = 3'b000;
  assign m_axi_data_awprot = 3'b000;

  // Data FSM
  reg [2:0] data_state;
  localparam DATA_IDLE       = 3'd0;
  localparam DATA_AR_PHASE   = 3'd1;
  localparam DATA_R_PHASE    = 3'd2;
  localparam DATA_AW_W_PHASE = 3'd3;
  localparam DATA_B_PHASE    = 3'd4;

  reg [31:0] data_addr_r;
  reg [31:0] data_wdata_r;
  reg [3:0]  data_be_r;
  reg        data_we_r;
  reg        aw_done;
  reg        w_done;

  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      data_state  <= DATA_IDLE;
      data_addr_r  <= 32'b0;
      data_wdata_r <= 32'b0;
      data_be_r    <= 4'b0;
      data_we_r    <= 1'b0;
      aw_done      <= 1'b0;
      w_done       <= 1'b0;
    end else begin
      if (data_req && (data_state == DATA_IDLE)) begin
        data_addr_r  <= data_addr;
        data_wdata_r <= data_wdata;
        data_be_r    <= data_be;
        data_we_r    <= data_we;
      end

      case (data_state)
        DATA_IDLE: begin
          aw_done <= 1'b0;
          w_done  <= 1'b0;
          if (data_req) begin
            if (!data_we) begin
              // READ
              if (m_axi_data_arready)
                data_state <= DATA_R_PHASE;
              else
                data_state <= DATA_AR_PHASE;
            end else begin
              // WRITE
              if (m_axi_data_awready && m_axi_data_wready) begin
                data_state <= DATA_B_PHASE;
              end else begin
                aw_done <= m_axi_data_awready;
                w_done  <= m_axi_data_wready;
                data_state <= DATA_AW_W_PHASE;
              end
            end
          end
        end
        DATA_AR_PHASE: begin
          if (m_axi_data_arready)
            data_state <= DATA_R_PHASE;
        end
        DATA_R_PHASE: begin
          if (m_axi_data_rvalid)
            data_state <= DATA_IDLE;
        end
        DATA_AW_W_PHASE: begin
          if (!aw_done && m_axi_data_awready)
            aw_done <= 1'b1;
          if (!w_done && m_axi_data_wready)
            w_done <= 1'b1;
          if ((aw_done || m_axi_data_awready) && (w_done || m_axi_data_wready))
            data_state <= DATA_B_PHASE;
        end
        DATA_B_PHASE: begin
          if (m_axi_data_bvalid)
            data_state <= DATA_IDLE;
        end
        default: data_state <= DATA_IDLE;
      endcase
    end
  end

  // Combinational outputs for data bridge
  reg        data_gnt_c;
  reg        data_rvalid_c;
  reg [31:0] data_rdata_c;
  reg        data_err_c;
  reg [31:0] data_araddr_c;
  reg        data_arvalid_c;
  reg        data_rready_c;
  reg [31:0] data_awaddr_c;
  reg        data_awvalid_c;
  reg [31:0] data_wdata_c;
  reg [3:0]  data_wstrb_c;
  reg        data_wvalid_c;
  reg        data_bready_c;

  always @(*) begin
    data_gnt_c     = 1'b0;
    data_rvalid_c  = 1'b0;
    data_rdata_c   = 32'b0;
    data_err_c     = 1'b0;
    data_araddr_c  = data_addr_r;
    data_arvalid_c = 1'b0;
    data_rready_c  = 1'b0;
    data_awaddr_c  = data_addr_r;
    data_awvalid_c = 1'b0;
    data_wdata_c   = data_wdata_r;
    data_wstrb_c   = data_be_r;
    data_wvalid_c  = 1'b0;
    data_bready_c  = 1'b0;

    case (data_state)
      DATA_IDLE: begin
        if (data_req) begin
          if (!data_we) begin
            data_araddr_c  = data_addr;
            data_arvalid_c = 1'b1;
            if (m_axi_data_arready)
              data_gnt_c = 1'b1;
          end else begin
            data_awaddr_c  = data_addr;
            data_awvalid_c = 1'b1;
            data_wdata_c   = data_wdata;
            data_wstrb_c   = data_be;
            data_wvalid_c  = 1'b1;
            if (m_axi_data_awready && m_axi_data_wready)
              data_gnt_c = 1'b1;
          end
        end
      end
      DATA_AR_PHASE: begin
        data_arvalid_c = 1'b1;
        if (m_axi_data_arready)
          data_gnt_c = 1'b1;
      end
      DATA_R_PHASE: begin
        data_rready_c = 1'b1;
        if (m_axi_data_rvalid) begin
          data_rvalid_c = 1'b1;
          data_rdata_c  = m_axi_data_rdata;
          data_err_c    = (m_axi_data_rresp != 2'b00);
        end
      end
      DATA_AW_W_PHASE: begin
        if (!aw_done) data_awvalid_c = 1'b1;
        if (!w_done)  data_wvalid_c  = 1'b1;
        if ((aw_done || m_axi_data_awready) && (w_done || m_axi_data_wready))
          data_gnt_c = 1'b1;
      end
      DATA_B_PHASE: begin
        data_bready_c = 1'b1;
        if (m_axi_data_bvalid) begin
          data_rvalid_c = 1'b1;
          data_err_c    = (m_axi_data_bresp != 2'b00);
        end
      end
      default: ;
    endcase
  end

  assign data_gnt    = data_gnt_c;
  assign data_rvalid = data_rvalid_c;
  assign data_rdata  = data_rdata_c;
  assign data_err    = data_err_c;

  assign m_axi_data_araddr  = data_araddr_c;
  assign m_axi_data_arvalid = data_arvalid_c;
  assign m_axi_data_rready  = data_rready_c;
  assign m_axi_data_awaddr  = data_awaddr_c;
  assign m_axi_data_awvalid = data_awvalid_c;
  assign m_axi_data_wdata   = data_wdata_c;
  assign m_axi_data_wstrb   = data_wstrb_c;
  assign m_axi_data_wvalid  = data_wvalid_c;
  assign m_axi_data_bready  = data_bready_c;

endmodule
