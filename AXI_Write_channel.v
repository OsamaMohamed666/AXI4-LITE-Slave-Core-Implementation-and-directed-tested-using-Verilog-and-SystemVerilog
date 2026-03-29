//=================================================================================================
//======================WRITE ADDRESS AND DATA CHANNELS (AW,W)
//=================================================================================================

// AXI allows independent AW and W channels,
// but this design serializes them internally for simplicity (AXI4-Lite)
// Design supports all ordering scenarios but processes one transaction at a time

module AXI_Write_channel(

  //GLOBAL SIGNALS
  input              clk,
  input              rst_n,


  //DATA CHANNEL
  input              w_valid,
  input  [31:0]      w_data,

  output reg [31:0]  slave_w_data,
  output reg         w_ready,


  //ADDRESS CHANNEL
  input      [31:0]  aw_addr,
  input              aw_valid,

  output reg  [31:0] slave_wr_addr, //output to slave
  output reg         aw_ready,

  //CONTROL FLAG: to indicate both channels are received and transaction is done
  output  reg       write_trans_done
);

  //state machine signals
  reg [1:0] cs,ns;
  localparam  idle_s = 2'b00,
              wait_for_data_s = 2'b01,
              wait_for_addr_s = 2'b10,
              write_is_done_s = 2'b11;



  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      slave_wr_addr <= 0;
      slave_w_data <= 0;
      cs <= idle_s;
    end

    else begin
      cs <= ns;

      if (aw_ready && aw_valid)
        slave_wr_addr <= aw_addr;

      if(w_ready && w_valid)
        slave_w_data <= w_data;
    end

  end

  //------------------------------------------
  // FSM COMBINATIONAL LOGIC
  //------------------------------------------
  always @ (*) begin
    //Default values to avoid inferred latches
    aw_ready = 1'b1;
    w_ready = 1'b1;
    write_trans_done = 1'b0;

    case (cs)
    idle_s :  begin
                //SLAVE IS READY TO RECEIVE BOTH DATA AND ADDR
                aw_ready = 1'b1;
                w_ready = 1'b1;

                //FIRST SCENARIO MASTER SEND BOTH SIMULTANEOUSLY
                if (aw_valid && aw_ready && w_valid && w_ready) begin
                  ns = write_is_done_s;
                end

                //SECOND SCENARIO AW CHANNEL IS THE ONLY VALID
                else if (aw_valid && aw_ready) begin
                  ns = wait_for_data_s;
                end

                // THIRD SCENARIO W CHANNEL IS THE ONLY VALID
                else if (w_valid && w_ready) begin
                  ns = wait_for_addr_s;
                end

                else
                  ns = cs;
              end

    wait_for_data_s : begin
                        w_ready = 1'b1;
                        // TELL MASTER TO STOP SENDING NEW ADDRESS AS IT WILL BE TREATED AS GARBAGE
                        aw_ready = 1'b0;

                        //WAIT TILL W VALID IS ASSERTED BY MASTER
                        if (w_valid && w_ready) begin
                          ns = write_is_done_s;
                        end

                        else
                          ns = cs;
                      end

    wait_for_addr_s : begin
                        aw_ready = 1'b1;
                        // TELL MASTER TO STOP SENDING NEW DATA AS IT WILL BE TREATED AS GARBAGE
                        w_ready = 1'b0;

                        //WAIT TILL AW VALID IS ASSERTED BY MASTER
                        if (aw_valid && aw_ready) begin
                          ns = write_is_done_s;
                        end

                        else
                          ns = cs;

                      end

    write_is_done_s : begin
                        w_ready = 1'b0;
                        aw_ready = 1'b0;
                        ns = idle_s;
                        //FLAG IS USED TO SEND REPSONSE AFTER THE WRITE TRANSACTION IS DONE
                        write_trans_done = 1'b1;
                      end
    default : begin
                ns = idle_s;
              end
    endcase
  end





endmodule



