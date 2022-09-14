module spi_master(
    input           clk     ,
    input           rst_n   ,

    input           req     ,
    input   [7:0]   din     ,
    output  [7:0]   dout    ,
    output          done    ,

    output          cs_n    ,
    output          mosi    ,
    input           miso    ,
    output          sclk        
      
);

//参数定义
    localparam  SCLK_PERIOD = 16,   
                SCLK_FALL   = 4 ,
                SCLK_RISE   = 12;
//信号定义
    reg [ 3:0]  cnt_sclk        ;
    wire        add_cnt_sclk    ;
    wire        end_cnt_sclk    ; 

    reg [ 3:0]  cnt_bit         ;
    wire        add_cnt_bit     ;
    wire        end_cnt_bit     ;

    reg         spi_sclk        ;
    reg         spi_mosi        ;
    reg [7:0]   rx_data         ;

//计数器
 
    always @(posedge clk or negedge rst_n) begin 
        if (rst_n==0) begin
            cnt_sclk <= 0; 
        end
        else if(add_cnt_sclk) begin
            if(end_cnt_sclk)
                cnt_sclk <= 0; 
            else
                cnt_sclk <= cnt_sclk+1 ;
       end
    end
    assign add_cnt_sclk = (req);
    assign end_cnt_sclk = add_cnt_sclk  && cnt_sclk == (SCLK_PERIOD)-1 ;
    
    always @(posedge clk or negedge rst_n) begin 
        if (rst_n==0) begin
            cnt_bit <= 0; 
        end
        else if(add_cnt_bit) begin
            if(end_cnt_bit)
                cnt_bit <= 0; 
            else
                cnt_bit <= cnt_bit+1 ;
       end
    end
    assign add_cnt_bit = (end_cnt_sclk);
    assign end_cnt_bit = add_cnt_bit  && cnt_bit == (8)-1 ;

//spi_sclk 模式3     
    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            spi_sclk <= 1'b1;
        end
        else if(cnt_sclk == SCLK_FALL-1)begin
            spi_sclk <= 1'b0;
        end
        else if(cnt_sclk == SCLK_RISE-1)begin
            spi_sclk <= 1'b1;
        end
    end
//发送数据
    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            spi_mosi <= 1'b0;
        end
        else if(cnt_sclk == SCLK_FALL-1)begin
            spi_mosi <= din[7-cnt_bit];
        end
    end
//接收数据
    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            rx_data <= 0;
        end
        else if(cnt_sclk == SCLK_RISE-1)begin
            rx_data[7-cnt_bit] <= miso;
        end
    end

//输出
    assign sclk = spi_sclk;
    assign mosi = spi_mosi;
    assign cs_n = ~req;
    assign done = end_cnt_bit;
    assign dout = rx_data;

endmodule 

