module ram (
    input  wire        clk,

    input  wire [31:0] addr,

    // Dữ liệu ghi từ CPU
    input  wire [31:0] wdata,

    // Byte write enable
    input  wire [3:0]  wstrb,

    // Dữ liệu đọc trả về CPU
    output wire [31:0] rdata
);

    // =========================================================
    // RAM 4KB = 1024 words × 32-bit
    // =========================================================

    reg [31:0] mem [0:1023];

    // =========================================================
    // ĐỌC RAM
    // =========================================================

    assign rdata = mem[addr[11:2]];

    // =========================================================
    // GHI RAM
    // =========================================================

    always @(posedge clk) begin

        // Byte 0
        if (wstrb[0])
            mem[addr[11:2]][7:0] <= wdata[7:0];

        // Byte 1
        if (wstrb[1])
            mem[addr[11:2]][15:8] <= wdata[15:8];

        // Byte 2  
        if (wstrb[2])
            mem[addr[11:2]][23:16] <= wdata[23:16];

        // Byte 3
        if (wstrb[3])
            mem[addr[11:2]][31:24] <= wdata[31:24];

    end

endmodule