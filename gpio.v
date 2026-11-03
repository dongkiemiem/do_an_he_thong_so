module gpio (
    input  wire        clk,
    input  wire        rst_n,

    // Tín hiệu ghi từ bus
    input  wire        wr_en,
    input  wire [31:0] wdata,

    // Output ra 6 LED
    output reg  [5:0]  gpio_out
);

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            // Tang Nano 9K LED active-low
            // 111111 = tat het LED
            gpio_out <= 6'b111111;
        end

        else if (wr_en) begin

            // CPU ghi dữ liệu vào thanh ghi GPIO
            gpio_out <= wdata[5:0];

        end

    end

endmodule