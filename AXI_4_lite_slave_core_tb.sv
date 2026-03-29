module AXI_4_lite_slave_core_tb();

 // GLOBAL SIGNALS
  bit         ACLK;
  bit         ARESETN;

  // WRITE ADDRESS (AW) CHANNEL
  bit   [31:0]      AWADDR;
  bit               AWVALID;
  logic             AWREADY;
  logic [31:0]      slave_wr_addr;

  // WRITE DATA (W) CHANNEL
  bit   [31:0]      WDATA;
  bit               WVALID;
  logic             WREADY;
  logic [31:0]      slave_w_data;


  // WRITE RESPONSE (B) CHANNEL
  bit         BREADY;
  logic       BVALID;
  logic       BRESP;

  // READ ADDRESS (AR) CHANNEL
  bit               ARVALID;
  bit   [31:0]      ARADDR;
  logic             ARREADY;
  logic [31:0]      slave_ar_addr;

  // READ DATA (R) CHANNEL
  bit               RREADY;
  bit   [31:0]      slave_r_data;
  logic [31:0]      RDATA;
  logic             RVALID;
  logic             RRESP;

  // Internal signals for testbench
  logic [31:0] injected_error; // To inject errors for testing error handling
  // For read
  logic [31:0] exp_rdata; // To hold expected read data for comparison when injecting errors
  logic [31:0] exp_araddr; // To hold expected read address for comparison when injecting errors
  // For write
  logic [31:0] exp_wdata; // To hold expected write data for comparison when injecting errors
  logic [31:0] exp_awaddr; // To hold expected write address for comparison when injecting errors

  //------------------------------------------
  // CLOCK AND RESET GENERATION
  //------------------------------------------
  always #5 ACLK = ~ACLK;

  initial begin
    ACLK = 0;
    ARESETN = 0;
    #10
    ARESETN = 1; // De-assert reset after 10 time units
  end

  initial begin
    $dumpfile("axi_4_lite_slave_core_tb.vcd");
    $dumpvars(0, AXI_4_lite_slave_core_tb);

    // Initialize signals
    AWADDR = 0;
    AWVALID = 0;
    WDATA = 0;
    WVALID = 0;
    BREADY = 0;
    ARVALID = 0;
    ARADDR = 0;
    RREADY = 0;

    // Wait for reset de-assertion
    //@(negedge ARESETN);
    @(posedge ARESETN);

    fork
      read_transaction();
      write_transaction();
    join
      #100
      $stop;
  end


  task read_transaction;
  begin
      //------------------------------------------------------------
      // INITIAL READ TRANSACTION SETUP
      //------------------------------------------------------------
      ARADDR = 32'hA; // Set read address (first transaction)
      slave_r_data = 32'hDEADBEEF; // Expected data returned from slave for this address
      ARVALID = 1; // Assert ARVALID to initiate address phase
      injected_error = 32'hBAD; // Value used for negative testing (stability checks)

      //------------------------------------------------------------
      // CHECK ADDRESS SAMPLING ON HANDSHAKE
      //------------------------------------------------------------
      @(negedge ACLK)
      // Verify that address is sampled ONLY when ARVALID & ARREADY handshake occurs
      comparing(ARADDR, slave_ar_addr,
        "ARADDR should be sampled by the slave when ARVALID and ARREADY are high","READ");

      exp_araddr = ARADDR; // Save correct sampled address for future stability checks

      // Inject error while ARVALID is still asserted
      // This tests that slave ignores changes until next transaction
      ARADDR = injected_error;

      //------------------------------------------------------------
      // CHECK ADDRESS STABILITY + DATA VALIDITY
      //------------------------------------------------------------
      @(negedge ACLK)
      // Address must remain stable inside slave (no re-sampling without new handshake)
      comparing(exp_araddr, slave_ar_addr,
        "[injecting error] ARADDR shouldn't be sampled by the slave as read transaction hasn't done yet","READ");

      // Check that RDATA reflects correct slave data when RVALID is asserted
      comparing(slave_r_data, RDATA,
        "RDATA should be valid data when RVALID is asserted","READ");

      exp_rdata = slave_r_data; // Save expected data

      // Inject error on slave data to test data stability at master side
      slave_r_data = injected_error;

      //------------------------------------------------------------
      // CHECK DATA STABILITY BEFORE HANDSHAKE COMPLETION
      //------------------------------------------------------------
      @(negedge ACLK)
      // Data must not change until R channel handshake completes
      comparing(exp_rdata, RDATA,
        "[injecting error] Slave read data shouldn't be sampled by the slave as read transaction hasn't done yet","READ");

      // End address phase
      ARVALID = 0; // De-assert ARVALID

      //------------------------------------------------------------
      // COMPLETE READ HANDSHAKE (R CHANNEL)
      //------------------------------------------------------------
      @(negedge ACLK)
      // Assert RREADY → completes handshake with slave
      RREADY = 1; // Now slave is allowed to update data/response

      @(negedge ACLK)
      // After handshake, RVALID should drop
      assert (!RVALID);

      //------------------------------------------------------------
      // BACK-TO-BACK TRANSACTION TEST
      //------------------------------------------------------------
      @(negedge ACLK)
      // Start new transaction immediately after previous handshake
      ARVALID = 1; // Assert ARVALID again
      ARADDR = 32'hB; // New address
      slave_r_data = 32'hBEEFDEAD; // New expected data

      // Save old data to ensure it doesn't change prematurely
      exp_rdata = RDATA;

      @(negedge ACLK)
      // Verify new address is sampled correctly
      comparing(ARADDR, slave_ar_addr,
        "ARADDR should be sampled by the slave when ARVALID and ARREADY are high","READ");

      //------------------------------------------------------------
      // CHECK NO EARLY DATA SAMPLING
      //------------------------------------------------------------
      // RVALID must NOT be asserted in same cycle as address handshake
      assert (!RVALID) else
        $error ("RDATA got sampled in same cycvle with ADDR");

      // Data must remain unchanged before RVALID is asserted
      comparing(exp_rdata, RDATA,
        "RDATA should stay the same as RVALID is low","READ");

      //------------------------------------------------------------
      // CHECK NEW DATA AFTER RVALID
      //------------------------------------------------------------
      @(negedge ACLK)
      // Now RVALID should be high → data must be updated correctly
      comparing(slave_r_data, RDATA,
        "RDATA should be valid data when RVALID is asserted","READ");

      //------------------------------------------------------------
      // CLEANUP
      //------------------------------------------------------------
      #40
      RREADY = 0; // De-assert RREADY (end of test)

  end
endtask


  task write_transaction;
  begin
      //------------------------------------------------------------
      // WRITE ADDRESS PHASE
      //------------------------------------------------------------
      AWADDR = 32'hA;
      AWVALID = 1;
      injected_error = 32'hBAD;

      @(negedge ACLK)
      comparing(AWADDR, slave_wr_addr, "AWADDR should be sampled when AWVALID & AWREADY are high","WRITE");
      exp_awaddr = AWADDR;

      // inject error while still valid
      AWADDR = injected_error;

      @(negedge ACLK)
      comparing(exp_awaddr, slave_wr_addr, "[injecting error] AWADDR shouldn't change before transaction completes","WRITE");

      //------------------------------------------------------------
      // WRITE DATA PHASE
      //------------------------------------------------------------
      WDATA = 32'hDEADBEEF;
      WVALID = 1;
      exp_wdata = WDATA;

      @(negedge ACLK)
      comparing(WDATA, slave_w_data, "WDATA should be sampled when WVALID & WREADY are high","WRITE");

      // inject error
      WDATA = injected_error;

      @(negedge ACLK)
      comparing(exp_wdata, slave_w_data, "[injecting error] WDATA shouldn't change before transaction completes","WRITE");

      //------------------------------------------------------------
      // COMPLETE WRITE (both addr + data received)
      //------------------------------------------------------------
      AWVALID = 0;
      WVALID  = 0;

      //------------------------------------------------------------
      // B CHANNEL CHECK
      //------------------------------------------------------------
      @(negedge ACLK)
      comparing(2'b00, BRESP, "BRESP should be OKAY when write completes","WRITE");

      //------------------------------------------------------------
      // HANDSHAKE WITH MASTER
      //------------------------------------------------------------
      BREADY = 1;

      @(negedge ACLK)
      assert (!BVALID) else
        $error("BVALID should deassert after handshake");

      //------------------------------------------------------------
      // BACK TO BACK TRANSACTION
      //------------------------------------------------------------
      AWADDR = 32'hB;
      WDATA  = 32'hBEEFDEAD;
      AWVALID = 1;
      WVALID  = 1;

      exp_wdata  = WDATA;
      exp_awaddr = AWADDR;

      @(negedge ACLK)
      comparing(AWADDR, slave_wr_addr, "Back-to-back: AWADDR should be sampled correctly","WRITE");
      comparing(WDATA, slave_w_data, "Back-to-back: WDATA should be sampled correctly","WRITE");

      // BVALID should not be same cycle
      assert (!BVALID) else
        $error("BVALID should not assert in same cycle as write sampling");

      @(negedge ACLK)
      comparing(2'b00, BRESP, "Back-to-back: BRESP should be OKAY","WRITE");

      //------------------------------------------------------------
      #40
      BREADY = 0;
      AWVALID = 0;
      WVALID  = 0;

  end
endtask


  int failed_tests_WRITE, passed_tests_WRITE;
  int failed_tests_READ, passed_tests_READ;
  int test_case_num;
  function automatic void comparing(input logic [31:0] expected,logic [31:0] actual,  string msg,trans_name);
  begin

    // Determine the test case number based on the transaction type
    if (trans_name == "WRITE") begin
      test_case_num = passed_tests_WRITE + failed_tests_WRITE; // Update test case number for write tests
    end
    else begin
      test_case_num = passed_tests_READ + failed_tests_READ; // Update test case number for read tests
    end

    // Compare expected and actual values and log the result
    if (expected != actual) begin
      $error("TEST CASE [%s] %0d FAILED: %s. Expected: 0x%h, Actual: 0x%h @ %0tns\n", trans_name,test_case_num, msg, expected, actual,$time);
      if (trans_name == "WRITE") begin
        failed_tests_WRITE++;
      end
      else begin
        failed_tests_READ++;
      end
      test_case_num++;
    end

    else begin
      $display("TEST CASE [%s] %0d PASSED: %s. Expected: 0x%h, Actual: 0x%h @ %0tns\n", trans_name,test_case_num, msg, expected, actual,$time);
      if (trans_name == "WRITE") begin
        passed_tests_WRITE++;
      end
      else begin
        passed_tests_READ++;
      end
    end
  end
  endfunction

  //------------------------------------------
  // DUT INSTANTIATION
  //------------------------------------------
  AXI_4_lite_slave_core DUT(
  .ACLK(ACLK),
  .ARESETN(ARESETN),

  .AWADDR(AWADDR),
  .AWVALID(AWVALID),
  .AWREADY(AWREADY),
  .slave_wr_addr(slave_wr_addr),

  .WDATA(WDATA),
  .WVALID(WVALID),
  .WREADY(WREADY),
  .slave_w_data(slave_w_data),

  .BREADY(BREADY),
  .BVALID(BVALID),
  .BRESP(BRESP),

  .ARVALID(ARVALID),
  .ARADDR(ARADDR),
  .ARREADY(ARREADY),
  .slave_ar_addr(slave_ar_addr),

  .RREADY(RREADY),
  .slave_r_data(slave_r_data),
  .RDATA(RDATA),
  .RVALID(RVALID),
  .RRESP(RRESP)
  );

endmodule
