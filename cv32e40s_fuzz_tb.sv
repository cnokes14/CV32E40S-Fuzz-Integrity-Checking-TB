`define ENABLE_PMP_TB
`define RANDOMIZE_ADDRESSES
`define RANDOMIZE_CONTROL

module cv32e40s_fuzz_tb import cv32e40s_pkg::*;; 
  logic                          clk_i;
  logic                          rst_ni;
  logic                          scan_cg_en_i;   // Enable all clock gates for testing

  // Static configuration
  logic [31:0]                   boot_addr_i;
  logic [31:0]                   dm_exception_addr_i;
  logic [31:0]                   dm_halt_addr_i;
  logic [31:0]                   mhartid_i;
  logic  [3:0]                   mimpid_patch_i;
  logic [31:0]                   mtvec_addr_i;

  // Instruction memory interface
  logic                          instr_req_o;
  logic                          instr_gnt_i;
  logic                          instr_rvalid_i;
  logic [31:0]                   instr_addr_o;
  logic [1:0]                    instr_memtype_o;
  logic [2:0]                    instr_prot_o;
  logic                          instr_dbg_o;
  logic [31:0]                   instr_rdata_i;
  logic                          instr_err_i;

  logic                          instr_reqpar_o;         // secure
  logic                          instr_gntpar_i;         // secure
  logic                          instr_rvalidpar_i;      // secure
  logic [12:0]                   instr_achk_o;           // secure
  logic [4:0]                    instr_rchk_i;           // secure

  // Data memory interface
  logic                          data_req_o;
  logic                          data_gnt_i;
  logic                          data_rvalid_i;
  logic [31:0]                   data_addr_o;
  logic [3:0]                    data_be_o;
  logic                          data_we_o;
  logic [31:0]                   data_wdata_o;
  logic [1:0]                    data_memtype_o;
  logic [2:0]                    data_prot_o;
  logic                          data_dbg_o;
  logic [31:0]                   data_rdata_i;
  logic                          data_err_i;

  logic                          data_reqpar_o;          // secure
  logic                          data_gntpar_i;          // secure
  logic                          data_rvalidpar_i;       // secure
  logic [12:0]                   data_achk_o;            // secure
  logic [4:0]                    data_rchk_i;            // secure

  // Cycle count
  logic [63:0]                   mcycle_o;

  // Basic interrupt architecture
  logic [31:0]                   irq_i;

  // Event wakeup signals
  logic                          wu_wfe_i;   // Wait-for-event wakeup

  // CLIC interrupt architecture
  logic                          clic_irq_i;
  logic [5-1:0]                  clic_irq_id_i;
  logic [ 7:0]                   clic_irq_level_i;
  logic [ 1:0]                   clic_irq_priv_i;
  logic                          clic_irq_shv_i;

  // Fence.i flush handshake
  logic                          fencei_flush_req_o;
  logic                          fencei_flush_ack_i;

    // Security Alerts
  logic                          alert_minor_o;          // secure
  logic                          alert_major_o;          // secure

  // Debug interface
  logic                          debug_req_i;
  logic                          debug_havereset_o;
  logic                          debug_running_o;
  logic                          debug_halted_o;
  logic                          debug_pc_valid_o;
  logic [31:0]                   debug_pc_o;

  // CPU control signals
  logic                          fetch_enable_i;
  logic                          core_sleep_o;
  
    cv32e40s_core 
        #(
`ifdef ENABLE_PMP_TB
            .PMP_NUM_REGIONS(16),
            //                     LOCK        ZEROS    ADDRESS MODE    READ    WRITE   EXECUTE
            .PMP_PMPNCFG_RV({{      1'b1,       2'b00,  PMP_MODE_TOR,   1'b0,   1'b0,   1'b0},  // REGION 15; All accesses forbidden
                             {      1'b0,       2'b00,  PMP_MODE_TOR,   1'b1,   1'b1,   1'b0},  // REGION 14; User-mode only R/W
                             {      1'b1,       2'b00,  PMP_MODE_TOR,   1'b0,   1'b0,   1'b0},  // REGION 13; All accesses forbidden
                             {      1'b0,       2'b00,  PMP_MODE_TOR,   1'b0,   1'b0,   1'b1},  // REGION 12; User-mode execute only
                             {      1'b0,       2'b00,  PMP_MODE_TOR,   1'b0,   1'b0,   1'b1},  // REGION 11; User-mode execute only
                             {      1'b0,       2'b00,  PMP_MODE_TOR,   1'b1,   1'b1,   1'b0},  // REGION 10; User-mode only R/W
                             {      1'b1,       2'b00,  PMP_MODE_TOR,   1'b0,   1'b0,   1'b1},  // REGION 9;  Machine execute only
                             {      1'b1,       2'b00,  PMP_MODE_TOR,   1'b0,   1'b0,   1'b0},  // REGION 8;  All accesses forbidden
                             {      1'b0,       2'b00,  PMP_MODE_TOR,   1'b1,   1'b1,   1'b0},  // REGION 7;  User-mode only R/W
                             {      1'b1,       2'b00,  PMP_MODE_TOR,   1'b0,   1'b0,   1'b0},  // REGION 6;  All accesses forbidden
                             {      1'b0,       2'b00,  PMP_MODE_TOR,   1'b0,   1'b0,   1'b1},  // REGION 5;  User-mode execute only
                             {      1'b0,       2'b00,  PMP_MODE_TOR,   1'b0,   1'b0,   1'b1},  // REGION 4;  User-mode execute only
                             {      1'b0,       2'b00,  PMP_MODE_TOR,   1'b1,   1'b1,   1'b0},  // REGION 3;  User-mode only R/W
                             {      1'b1,       2'b00,  PMP_MODE_TOR,   1'b0,   1'b0,   1'b1},  // REGION 2;  Machine execute only
                             {      1'b0,       2'b00,  PMP_MODE_TOR,   1'b0,   1'b0,   1'b0},  // REGION 1;  All accesses forbidden
                             {      1'b0,       2'b00,  PMP_MODE_TOR,   1'b0,   1'b0,   1'b0}}),// REGION 0;  All accesses forbidden
            // Addresses
            .PMP_PMPADDR_RV({32'hF0000000,      // REGION 15 - space above this is to check out of bounds access
                             32'hE0000000,      // REGION 14
                             32'hD0000000,      // REGION 13
                             32'hC0000000,      // REGION 12
                             32'hB0000000,      // REGION 11
                             32'hA0000000,      // REGION 10
                             32'h90000000,      // REGION 9
                             32'h80000000,      // REGION 8
                             32'h70000000,      // REGION 7
                             32'h60000000,      // REGION 6
                             32'h50000000,      // REGION 5
                             32'h40000000,      // REGION 4
                             32'h30000000,      // REGION 3
                             32'h20000000,      // REGION 2
                             32'h10000000,      // REGION 1
                             32'h08000000}),    // REGION 0
            // MACHINE SECURITY CONFIG          RLB         MMWP        MML
            .PMP_MSECCFG_RV({       29'h0,      1'b0,       1'b1,       1'b1})
`endif
        ) core_dut (
            .clk_i(clk_i),
            .rst_ni(rst_ni),
            .scan_cg_en_i(scan_cg_en_i),
            .boot_addr_i(boot_addr_i),
            .dm_exception_addr_i(dm_exception_addr_i),
            .dm_halt_addr_i(dm_halt_addr_i),
            .mhartid_i(mhartid_i),
            .mimpid_patch_i(mimpid_patch_i),
            .mtvec_addr_i(mtvec_addr_i),
            .instr_req_o(instr_req_o),
            .instr_gnt_i(instr_gnt_i),
            .instr_rvalid_i(instr_rvalid_i),
            .instr_addr_o(instr_addr_o),
            .instr_memtype_o(instr_memtype_o),
            .instr_prot_o(instr_prot_o),
            .instr_dbg_o(instr_dbg_o),
            .instr_rdata_i(instr_rdata_i),
            .instr_err_i(instr_err_i),
            .instr_reqpar_o(instr_reqpar_o),
            .instr_gntpar_i(instr_gntpar_i),
            .instr_rvalidpar_i(instr_rvalidpar_i),
            .instr_achk_o(instr_achk_o),
            .instr_rchk_i(instr_rchk_i),
            .data_req_o(data_req_o),
            .data_gnt_i(data_gnt_i),
            .data_rvalid_i(data_rvalid_i),
            .data_addr_o(data_addr_o),
            .data_be_o(data_be_o),
            .data_we_o(data_we_o),
            .data_wdata_o(data_wdata_o),
            .data_memtype_o(data_memtype_o),
            .data_prot_o(data_prot_o),
            .data_dbg_o(data_dbg_o),
            .data_rdata_i(data_rdata_i),
            .data_err_i(data_err_i),
            .data_reqpar_o(data_reqpar_o),
            .data_gntpar_i(data_gntpar_i),
            .data_rvalidpar_i(data_rvalidpar_i),
            .data_achk_o(data_achk_o),
            .data_rchk_i(data_rchk_i),
            .mcycle_o(mcycle_o),
            .irq_i(irq_i),
            .wu_wfe_i(wu_wfe_i),
            .clic_irq_i(clic_irq_i),
            .clic_irq_id_i(clic_irq_id_i),
            .clic_irq_level_i(clic_irq_level_i),
            .clic_irq_priv_i(clic_irq_priv_i),
            .clic_irq_shv_i(clic_irq_shv_i),
            .fencei_flush_req_o(fencei_flush_req_o),
            .fencei_flush_ack_i(fencei_flush_ack_i),
            .alert_minor_o(alert_minor_o),
            .alert_major_o(alert_major_o),
            .debug_req_i(debug_req_i),
            .debug_havereset_o(debug_havereset_o),
            .debug_running_o(debug_running_o),
            .debug_halted_o(debug_halted_o),
            .debug_pc_valid_o(debug_pc_valid_o),
            .debug_pc_o(debug_pc_o),
            .fetch_enable_i(fetch_enable_i),
            .core_sleep_o(core_sleep_o)
        );

initial begin
    $srandom(1); // Seed
    $timeformat(-9, 2, " ns", 20);
    clk_i = 1'b0;
    debug_req_i = 1'b0;
    rst_ni = 1'b0;
    scan_cg_en_i = 1'b0;
    std::randomize(boot_addr_i);
    std::randomize(dm_exception_addr_i);
    std::randomize(dm_halt_addr_i);
    std::randomize(mhartid_i);
    std::randomize(mimpid_patch_i);
    std::randomize(mtvec_addr_i);
    #5ns;
    clk_i = 1'b1;
    #5ns;
    rst_ni = 1'b1;
    for(int idx = 0; idx < 1000000; idx++) begin
        clk_i = ~clk_i;
        std::randomize(instr_gnt_i);
        std::randomize(instr_rvalid_i);
        std::randomize(instr_rdata_i);
        std::randomize(instr_err_i);
        std::randomize(data_gnt_i);
        std::randomize(data_rvalid_i);
        std::randomize(data_rdata_i);
        std::randomize(data_err_i);
        std::randomize(data_gntpar_i);
        std::randomize(data_rvalidpar_i);
        std::randomize(data_rchk_i);
        std::randomize(irq_i);
        std::randomize(wu_wfe_i);
        std::randomize(clic_irq_i);
        std::randomize(clic_irq_id_i);
        std::randomize(clic_irq_level_i);
        std::randomize(clic_irq_priv_i);
        std::randomize(clic_irq_shv_i);
        std::randomize(fencei_flush_ack_i);
        std::randomize(fetch_enable_i);
        std::randomize(instr_gntpar_i);
        std::randomize(instr_rvalidpar_i);
        std::randomize(instr_rchk_i);
`ifdef RANDOMIZE_ADDRESSES
        std::randomize(boot_addr_i);
        std::randomize(dm_exception_addr_i);
        std::randomize(dm_halt_addr_i);
        std::randomize(mhartid_i);
        std::randomize(mimpid_patch_i);
        std::randomize(mtvec_addr_i);
`endif
`ifdef RANDOMIZE_CONTROL
        std::randomize(debug_req_i);
        std::randomize(rst_ni);
        std::randomize(scan_cg_en_i);
`endif
        #5ns;
        clk_i = ~clk_i;
        if($isunknown(instr_req_o)) begin
            $error("Got an X in the instruction request! Address: %08x at time %0t", instr_addr_o, $time);
        end
        #5ns;
    end
    $finish;
end
endmodule
