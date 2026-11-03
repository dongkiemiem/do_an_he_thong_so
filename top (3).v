module uart(
	
	 input  wire	clk,   
    input   sys_rst_n,     // reset input
    output  reg led,        // LED
	 inout  wire	TX_PIN,
	 inout  wire	RX_PIN		
);
//Init module UART
wire txBusy;
wire rdy;
wire [7:0] rx_data;
reg [7:0] tx_data;
reg writeEN;
reg rdyClr;

wire rxclk_en, txclk_en;

baud_rate_gen uart_baud(
	.clk(clk),
	.rxclk_en(rxclk_en),
	.txclk_en(txclk_en)
);

transmitter uart_tx(
	.tx(TX_PIN),
	.din(tx_data),
	.clk(clk),
	.clken(txclk_en),
	.wr_en(writeEN),
	.tx_busy(txBusy)
);

receiver uart_rx(
	.rx(RX_PIN),
	.data(rx_data),
	.clk(clk),
	.clken(rxclk_en),
	.rdy(rdy),
	.rdy_clr(rdyClr)
);

//always @(posedge clk ) begin // Counter block
//    if (!sys_rst_n)
//        counter <= 24'd0;
//    else if (counter < 24'd1349_9999)       // 0.5s delay
//        counter <= counter + 1'b1;
//    else
//        counter <= 24'd0;
//end

//always @(posedge clk) begin // Toggle LED
//    if (!sys_rst_n)
//        led <= 1'b1;
//    else if (counter == 24'd1349_9999)       // 0.5s delay
//        led <= ~led;                         // ToggleLED
//end

always @(posedge clk) 
begin
    if (txBusy) 
        writeEN <= 0;
    else if (rdy && rdyClr != 1) begin
        rdyClr <= 1'b1; 
        writeEN <= 1'b1;
        tx_data <= rx_data;
    end


    if (rdyClr) begin
         rdyClr <= 0;
    end
end
endmodule
