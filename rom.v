module rom (
    input  wire [31:0] addr,
    output wire [31:0] rdata
);

    // =========================================================
    // ROM 4KB = 1024 words × 32-bit
    // =========================================================

    reg [31:0] mem [0:1023];

    // Nạp chương trình vào ROM khi FPGA khởi động
    initial begin
        $readmemh("firmware.hex", mem);
    end

    // Đọc dữ liệu từ ROM
    // addr[11:2] tạo chỉ số từ 0 đến 1023
    assign rdata = mem[addr[11:2]];

endmodule                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   