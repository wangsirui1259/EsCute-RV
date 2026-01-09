`include "include/defines.svh"

module RegisterF (
    input  logic        clk,
    // input  logic            rst_n,
    input  logic        rf_we,
    // 读地址端口
    input  logic [ 4:0] rR1,
    input  logic [ 4:0] rR2,
    // 写地址端口1 (主流水线)
    input  logic [ 4:0] wR,
    // 写数据端口1 (主流水线)
    input  logic [31:0] wD,
    // 写端口2 (乘法器)
    input  logic        rf_we2,
    input  logic [ 4:0] wR2,
    input  logic [31:0] wD2,
    // 读数据端口
    output logic [31:0] rD1,
    output logic [31:0] rD2
);

    logic [31:0] rf_in[32];  // 32个寄存器 unpacked 维度使用 [32]

    // 初始化：x0 = 0
    // 便于Yosys综合识别
    initial begin
        rf_in[0] = '0;  // 初始 x0 = 0
    end

    // 写入使用时序逻辑 - 支持双写端口
    // 当两个端口同时写入同一寄存器时主流水线端口优先
    // 因乘法为长指令 后写回的短指令在时序上更靠后因此结果更新
    // 应当采用更新的寄存器值
    always_ff @(posedge clk) begin
        // 主流水线写端口
        if (rf_we && wR != 5'd0) begin
            rf_in[wR] <= wD;
        end
        // 乘法器写端口（优先级更低）
        if (rf_we2 && wR2 != 5'd0 && !(rf_we && wR == wR2)) begin
            rf_in[wR2] <= wD2;
        end
    end

    // 读取使用组合逻辑
    // 实现写优先（write-through）：如果当前周期正在写入的寄存器被读取，
    // 则直接返回写入的数据而不是寄存器堆中的旧值
    // 这解决了分支跳转后立即读取刚写入寄存器的冒险问题
    always_comb begin
        // 读端口1：检查是否与写端口冲突
        if (rR1 == 0) begin
            rD1 = {32{1'b0}};  // x0寄存器恒为0
        end else if (rf_we && wR == rR1) begin
            rD1 = wD;  // 写优先：返回正在写入的值
        end else if (rf_we2 && wR2 == rR1 && !(rf_we && wR == rR1)) begin
            rD1 = wD2;  // 乘法器写端口优先（当主端口不写同一寄存器时）
        end else begin
            rD1 = rf_in[rR1];
        end
        
        // 读端口2：检查是否与写端口冲突
        if (rR2 == 0) begin
            rD2 = {32{1'b0}};  // x0寄存器恒为0
        end else if (rf_we && wR == rR2) begin
            rD2 = wD;  // 写优先：返回正在写入的值
        end else if (rf_we2 && wR2 == rR2 && !(rf_we && wR == rR2)) begin
            rD2 = wD2;  // 乘法器写端口优先（当主端口不写同一寄存器时）
        end else begin
            rD2 = rf_in[rR2];
        end
    end

endmodule
