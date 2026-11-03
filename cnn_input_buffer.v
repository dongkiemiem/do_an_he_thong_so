
module cnn_input_buffer (
    input wire clk,
    input wire rst_n,

    input wire clear,

    input wire write_en,
    input wire [7:0] write_data,

    input wire [9:0] read_addr,
    output reg [7:0] read_data,

    output reg [9:0] write_count,
    output wire full
);

    // Bo nho luu 784 pixel
    reg [7:0] buffer [0:783];

    // Bao hieu bo nho da day
    assign full = (write_count == 10'd784);

    // Ghi pixel
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_count <= 10'd0;
        end
        else if (clear) begin
            write_count <= 10'd0;
        end
        else if (write_en && !full) begin
            buffer[write_count] <= write_data;
            write_count <= write_count + 10'd1;
        end
    end

    // Doc RAM dong bo
    always @(posedge clk) begin
        if (read_addr < 10'd784)
            read_data <= buffer[read_addr];
        else
            read_data <= 8'd0;
    end

endmodule
