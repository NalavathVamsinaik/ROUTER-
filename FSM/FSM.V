`timescale 1ns / 1ps


//ROUTER FSM 

module FSM_ROUTER(clk, rst, pkt_valid, parity_done, data_in, soft_rst_0, soft_rst_1,
                    soft_rst_2, fifo_full, low_pkt_valid, fifo_empty_0, fifo_empty_1, fifo_empty_2, 
                    detect_addr, ld_state, laf_state, full_state, wr_en_reg,  rst_int_reg, lfd_state,busy

    );
    input clk, rst, pkt_valid, parity_done, soft_rst_0, soft_rst_1, soft_rst_2;  
    input [1:0]data_in;                                                                  // destination bits 
    input fifo_full, low_pkt_valid, fifo_empty_0, fifo_empty_1, fifo_empty_2;        
    output detect_addr, ld_state, laf_state, full_state; 
    output wr_en_reg, rst_int_reg, lfd_state, busy;
    
    parameter   DECODE_ADDRESS    = 3'b000,
                LOAD_FIRST_DATA    = 3'b001,
                LOAD_DATA          = 3'b010,
                LOAD_PARITY        = 3'b011,
                CHECK_PARITY_ERROR = 3'b100,
                FIFO_FULL_STATE    = 3'b101,
                LOAD_AFTER_FULL    = 3'b110,
                WAIT_TILL_EMPTY    = 3'b111;
           
    reg [2:0]PS,NS;   // PRESENT STATE AND NEXT STATE 
    reg [1:0] temp;    

// TEMP_LOGIC
 

always@(*)
 begin
    if(rst)
        temp <= 0;
    else if(detect_addr)
        temp <= data_in;
    else
       temp <= temp;
 end 
 
// PRESENT STATE LOGIC

always@(*)
    begin
      if(~rst)
         PS <= DECODE_ADDRESS;
    else if((soft_rst_0||soft_rst_1||soft_rst_2)||
            (soft_rst_0 && temp == 2'b00)||(soft_rst_1 && temp == 2'b01)||(soft_rst_2 && temp == 2'b10));
    else
        PS <= NS;
    end

// NEXT STATE LOGIC

always@(*)
  begin
   case(PS)
        DECODE_ADDRESS:
              begin
                    if((pkt_valid && data_in[1:0]==0 && fifo_empty_0)||
                      (pkt_valid && data_in[1:0]==1 && fifo_empty_1)||
                      (pkt_valid && data_in[1:0]==2 && fifo_empty_2))
                    
                      NS <= LOAD_FIRST_DATA;
                      
                    else if((pkt_valid && data_in[1:0]==0  && fifo_empty_0)||
                             (pkt_valid && data_in[1:0]==1 && fifo_empty_1)||
                             (pkt_valid && data_in[1:0]==2 && fifo_empty_2))
                    
                    NS <= WAIT_TILL_EMPTY;
                    
                    else
                         NS <= DECODE_ADDRESS;  
             end 
   
        LOAD_FIRST_DATA :
                    NS <= LOAD_DATA;                  
         
     LOAD_DATA:
            begin 
                  if(~fifo_empty_0 && pkt_valid)
                        NS <= LOAD_PARITY;
                  else if(fifo_full)
                       NS <= FIFO_FULL_STATE;
                  else
                     NS = LOAD_DATA;
            end
   
     FIFO_FULL_STATE:
                begin
                      if(~fifo_full)
                            NS <= LOAD_AFTER_FULL;
                      else if(fifo_full)
                            NS <= FIFO_FULL_STATE;
                      else
                          NS <= FIFO_FULL_STATE;
                end
                
    LOAD_AFTER_FULL:
                begin
                    if(~parity_done && ~low_pkt_valid )
                        NS <= LOAD_DATA;
                    else if(parity_done)
                        NS <= DECODE_ADDRESS;
                    else if(~parity_done && low_pkt_valid)
                       NS <= LOAD_PARITY;       
                    else
                       NS <= LOAD_AFTER_FULL; 
                end
     LOAD_PARITY:
              begin
                   NS <= CHECK_PARITY_ERROR;
              end
  
     CHECK_PARITY_ERROR:
                    begin
                        if(~fifo_full)
                           NS <= DECODE_ADDRESS;
                        else if(fifo_full)
                           NS <= FIFO_FULL_STATE;     
                        else
                           NS <= CHECK_PARITY_ERROR;    
                    end
                    
     WAIT_TILL_EMPTY:
                begin
                  if((fifo_empty_0 && temp==0)||
                     (fifo_empty_1 && temp==1)||
                     (fifo_empty_2 && temp==2))
                   NS <= LOAD_FIRST_DATA;
                 else if((~fifo_empty_0 && ~temp==0)||
                         (~fifo_empty_1 && ~temp==1)||
                         (~fifo_empty_2 && ~temp==2))
                    NS <= WAIT_TILL_EMPTY;
                 else
                   NS <= WAIT_TILL_EMPTY;
               end                
endcase
end 

    assign detect_addr = (PS == DECODE_ADDRESS)?1:0;
    assign ld_state    = (PS == LOAD_DATA)?1:0;
    assign laf_state   = (PS == LOAD_AFTER_FULL)?1:0;
    assign full_state  = (PS == FIFO_FULL_STATE)?1:0;
    assign wr_en_reg   = (PS == LOAD_DATA || PS == LOAD_AFTER_FULL || PS == LOAD_PARITY)?1:0;
    assign rst_int_reg = (PS == CHECK_PARITY_ERROR)?1:0;
    assign busy        = (PS ==LOAD_FIRST_DATA)||(PS == FIFO_FULL_STATE) || (PS == LOAD_AFTER_FULL) || (PS == LOAD_PARITY) ||
                         (PS == CHECK_PARITY_ERROR) || (PS == WAIT_TILL_EMPTY)?1:0;
    assign lfd_state   = (PS == LOAD_FIRST_DATA)?1:0;
   

endmodule
