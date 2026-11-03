
module cnn_accelerator (
    input wire clk,
    input wire rst_n,

    input wire start,

    output reg busy,
    output reg done,

    output reg [9:0] pixel_addr,
    input wire [7:0] pixel_data,

    output reg [31:0] result
);

    reg [3:0] pixel_index;
    reg [31:0] pixel_sum;
    reg [2:0] state;

    localparam IDLE     = 3'd0;
    localparam SET_ADDR = 3'd1;
    localparam WAIT_1   = 3'd2;
    localparam WAIT_2   = 3'd3;
    localparam READ_DATA= 3'd4;
    localparam FINISH   = 3'd5;

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            state       <= IDLE;
            busy        <= 1'b0;
            done        <= 1'b0;
            pixel_addr  <= 10'd0;
            pixel_index <= 4'd0;
            pixel_sum   <= 32'd0;
            result      <= 32'd0;
        end

        else begin

            case (state)

                // Cho CPU gui lenh START
                IDLE: begin
                    busy <= 1'b0;

                    if (start) begin
                        busy        <= 1'b1;
                        done        <= 1'b0;
                        pixel_index <= 4'd0;
                        pixel_sum   <= 32'd0;
                        state       <= SET_ADDR;
                    end
                end

                // Chon dia chi pixel can doc
                SET_ADDR: begin
                    case (pixel_index)
                        4'd0: pixel_addr <= 10'd0;
                        4'd1: pixel_addr <= 10'd1;
                        4'd2: pixel_addr <= 10'd2;

                        4'd3: pixel_addr <= 10'd28;
                        4'd4: pixel_addr <= 10'd29;
                        4'd5: pixel_addr <= 10'd30;

                        4'd6: pixel_addr <= 10'd56;
                        4'd7: pixel_addr <= 10'd57;
                        4'd8: pixel_addr <= 10'd58;

                        default: pixel_addr <= 10'd0;
                    endcase

                    state <= WAIT_1;
                end

                // Cho bo dem cap nhat dia chi doc
                WAIT_1: begin
                    state <= WAIT_2;
                end

                // Cho du lieu pixel on dinh
                WAIT_2: begin
                    state <= READ_DATA;
                end

                // Cong pixel vao tong
                READ_DATA: begin

                    if (pixel_index == 4'd8) begin
                        result <= pixel_sum + pixel_data;
                        state  <= FINISH;
                    end

                    else begin
                        pixel_sum   <= pixel_sum + pixel_data;
                        pixel_index <= pixel_index + 4'd1;
                        state       <= SET_ADDR;
                    end

                end

                // Bao hoan thanh va GIU done = 1
                FINISH: begin
                    busy  <= 1'b0;
                    done  <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    busy  <= 1'b0;
                end

            endcase
        end
    end

endmodule