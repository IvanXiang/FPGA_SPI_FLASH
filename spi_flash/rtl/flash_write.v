module flash_write(

    input               clk         ,
    input               rst_n       ,
    
    //key
    input               write       ,
    input   [ 7:0]      wr_data     ,//写入的数据
    input   [23:0]      wr_addr     ,//flash写地址

    //spi_master
    output              trans_req   ,
    output  [7:0]       tx_dout     ,
    input   [7:0]       rx_din      ,
    input               trans_done  ,

    //output
    output  [47:0]      dout        ,
    output  [5:0]       dout_mask   ,
    output              dout_vld    
);

//参数定义
    //主状态机状态参数
    localparam  M_IDLE = 5'b0_0001,
                M_WREN = 5'b0_0010,//主机发写使能序列
                M_SE   = 5'b0_0100,//主机发扇区擦除序列
                M_RDSR = 5'b0_1000,//主机发读状态寄存器序列
                M_PP   = 5'b1_0000;//主机发页编程序列
    //从状态机状态参数
    localparam  S_IDLE = 5'b0_0001,
                S_CMD  = 5'b0_0010,//发送命令
                S_ADDR = 5'b0_0100,//发送地址
                S_DATA = 5'b0_1000,//发送数据、接收数据
                S_DELA = 5'b1_0000;//延时 拉高片选信号

    localparam  CMD_WREN = 8'h06,//写使能命令
                CMD_SE   = 8'hD8,//擦除命令
                CMD_RDSR = 8'h05,//读状态寄存器命令
                CMD_PP   = 8'h02;//页编程命令

    parameter   TIME_DELAY = 16,//发完WREN、SE、PP序列 拉高片选
                TIME_SE    = 150_000_000,//扇区擦除3s
                TIME_PP    = 25_000,//页编程5ms
                TIME_RDSR  = 2000;//读状态寄存器 最大2000次

//信号定义

    reg         [4:0]       m_state_c       ;
    reg         [4:0]       m_state_n       ;
    reg         [4:0]       s_state_c       ;
    reg         [4:0]       s_state_n       ;

    reg         [3:0]       cnt0            ;
    wire                    add_cnt0        ;
    wire                    end_cnt0        ;
    reg         [3:0]       xx              ;

    reg         [31:0]      cnt1            ;
    wire                    add_cnt1        ;
    wire                    end_cnt1        ;
	reg			[31:0]      yy				;

    reg                     rdsr_wip        ;
    reg                     rdsr_wel        ;
    reg         [2:0]       flag            ;
    
    reg         [7:0]       tx_data         ;
    reg                     tx_req          ;
    
    reg         [47:0]      data            ;
    reg         [5:0]       data_mask       ;
    reg                     data_vld        ;

    wire                    m_idle2m_wren   ; 
    wire                    m_wren2m_se     ; 
    wire                    m_se2m_rdsr     ; 
    wire                    m_rdsr2m_wren   ; 
    wire                    m_rdsr2m_pp     ; 
    wire                    m_wren2m_pp     ; 
    wire                    m_rdsr2m_idle   ; 
    wire                    m_pp2m_rdsr     ; 

    wire                    s_idle2s_cmd    ; 
    wire                    s_cmd2s_addr    ; 
    wire                    s_cmd2s_data    ; 
    wire                    s_cmd2s_dela    ; 
    wire                    s_addr2s_data   ; 
    wire                    s_addr2s_dela   ; 
    wire                    s_data2s_dela   ; 
    wire                    s_dela2s_idle   ; 

//状态机设计
    always @(posedge clk or negedge rst_n) begin 
        if (rst_n==0) begin
            m_state_c <= M_IDLE ;
        end
        else begin
            m_state_c <= m_state_n;
       end
    end
    
    always @(*) begin 
        case(m_state_c)  
            M_IDLE :begin
                if(m_idle2m_wren)
                    m_state_n = M_WREN ;
                else 
                    m_state_n = m_state_c ;
            end
            M_WREN :begin
                if(m_wren2m_se)
                    m_state_n = M_SE ;
                else if(m_wren2m_pp)
                    m_state_n = M_PP ;
                else 
                    m_state_n = m_state_c ;
            end
            M_SE :begin
                if(m_se2m_rdsr)
                    m_state_n = M_RDSR ;
                else 
                    m_state_n = m_state_c ;
            end
            M_RDSR :begin
                if(m_rdsr2m_wren)
                    m_state_n = M_WREN ;
                else if(m_rdsr2m_pp)
                    m_state_n = M_PP ;
                else if(m_rdsr2m_idle)
                    m_state_n = M_IDLE ;
                else 
                    m_state_n = m_state_c ;
            end
            M_PP :begin
                if(m_pp2m_rdsr)
                    m_state_n = M_RDSR ;
                else 
                    m_state_n = m_state_c ;
            end
            default : m_state_n = M_IDLE ;
        endcase
    end
    
    assign m_idle2m_wren = m_state_c==M_IDLE && (write);
    assign m_wren2m_se   = m_state_c==M_WREN && (s_dela2s_idle && flag[0]);
    assign m_se2m_rdsr   = m_state_c==M_SE   && (s_dela2s_idle);
    assign m_rdsr2m_wren = m_state_c==M_RDSR && (s_dela2s_idle && ~rdsr_wel && ~rdsr_wip && flag[1]);
    assign m_rdsr2m_pp   = m_state_c==M_RDSR && (s_dela2s_idle && rdsr_wel && ~rdsr_wip && flag[1]);
    assign m_wren2m_pp   = m_state_c==M_WREN && (s_dela2s_idle && flag[1]);
    assign m_rdsr2m_idle = m_state_c==M_RDSR && (s_dela2s_idle && flag[2]);
    assign m_pp2m_rdsr   = m_state_c==M_PP   && (s_dela2s_idle);
    
 //从状态机设计
        
    always @(posedge clk or negedge rst_n) begin 
        if (rst_n==0) begin
            s_state_c <= S_IDLE ;
        end
        else begin
            s_state_c <= s_state_n;
       end
    end
    
    always @(*) begin 
        case(s_state_c)  
            S_IDLE :begin
                if(s_idle2s_cmd)
                    s_state_n = S_CMD ;
                else 
                    s_state_n = s_state_c ;
            end
            S_CMD :begin
                if(s_cmd2s_addr)
                    s_state_n = S_ADDR ;
                else if(s_cmd2s_data)
                    s_state_n = S_DATA ;
                else if(s_cmd2s_dela)
                    s_state_n = S_DELA ;
                else 
                    s_state_n = s_state_c ;
            end
            S_ADDR :begin
                if(s_addr2s_data)
                    s_state_n = S_DATA ;
                else if(s_addr2s_dela)
                    s_state_n = S_DELA ;
                else 
                    s_state_n = s_state_c ;
            end
            S_DATA :begin
                if(s_data2s_dela)
                    s_state_n = S_DELA ;
                else 
                    s_state_n = s_state_c ;
            end
            S_DELA :begin
                if(s_dela2s_idle)
                    s_state_n = S_IDLE ;
                else 
                    s_state_n = s_state_c ;
            end
            default : s_state_n = S_IDLE ;
        endcase
    end
    
    assign s_idle2s_cmd  = s_state_c==S_IDLE && (m_state_c != M_IDLE);
    assign s_cmd2s_addr  = s_state_c==S_CMD  && (trans_done && (m_state_c == M_SE || m_state_c == M_PP));
    assign s_cmd2s_data  = s_state_c==S_CMD  && (trans_done && m_state_c == M_RDSR);
    assign s_cmd2s_dela  = s_state_c==S_CMD  && (trans_done && m_state_c == M_WREN);
    assign s_addr2s_data = s_state_c==S_ADDR && (end_cnt0 && (m_state_c == M_RDSR || m_state_c == M_PP));
    assign s_addr2s_dela = s_state_c==S_ADDR && (end_cnt0 && m_state_c == M_SE);
    assign s_data2s_dela = s_state_c==S_DATA && (end_cnt0 && m_state_c == M_PP || m_state_c == M_RDSR && end_cnt1);
    assign s_dela2s_idle = s_state_c==S_DELA && (end_cnt1);
    
    //计数器设计
    
    always @(posedge clk or negedge rst_n) begin 
        if (rst_n==0) begin
            cnt0 <= 0; 
        end
        else if(add_cnt0) begin
            if(end_cnt0)
                cnt0 <= 0; 
            else
                cnt0 <= cnt0+1 ;
       end
    end
    assign add_cnt0 = (m_state_c != M_RDSR && trans_done);
    assign end_cnt0 = add_cnt0 && cnt0 == (xx)-1 ;
    
    always  @(*)begin
        if(s_state_c == S_CMD)  //发命令1字节
            xx = 1;
        else if(s_state_c == S_ADDR)    //发地址3字节
            xx = 3;
        else /*if(s_state_c == S_DATA)*/ //发数据1字节
            xx = 4;
    end
    
    always @(posedge clk or negedge rst_n) begin 
        if (rst_n==0) begin
            cnt1 <= 0; 
        end
        else if(add_cnt1) begin
            if(end_cnt1)
                cnt1 <= 0; 
            else
                cnt1 <= cnt1+1 ;
       end
    end
    assign add_cnt1 = (s_state_c == S_DELA || m_state_c == M_RDSR && s_state_c == S_DATA && trans_done);
    assign end_cnt1 = add_cnt1  && (cnt1 == (yy)-1 || trans_done && ~rdsr_wip);
    
    always  @(*)begin
        if((m_state_c == M_WREN || m_state_c == M_RDSR) && s_state_c == S_DELA)  //发完写使能延时
            yy = TIME_DELAY;
        else if(m_state_c == M_SE)//发完擦除延时
            yy = TIME_SE;
        else if(m_state_c == M_PP)//发完页编程延时
            yy = TIME_PP;
        else if(m_state_c == M_RDSR && s_state_c == S_DATA)//读状态寄存器值 yy 次
            yy = TIME_RDSR;
	     else 
		    yy = TIME_DELAY;
    end

//rdsr_wel rdsr_wip
    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            rdsr_wel <= 1'b0;
            rdsr_wip <= 1'b0;
        end
        else if(m_state_c == M_RDSR && s_state_c == S_DATA && trans_done)begin
            rdsr_wel <= rx_din[1];
            rdsr_wip <= rx_din[0];
        end
    end

    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            flag <= 3'b000;
        end
        else if(m_idle2m_wren)begin
            flag <= 3'b001;
        end
        else if(m_se2m_rdsr)begin
            flag <= 3'b010;
        end
        else if(m_pp2m_rdsr)begin
            flag <= 3'b100;
        end
    end

//输出    

    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            tx_data <= 0;
        end
        else if(m_state_c == M_WREN)begin
            tx_data <= CMD_WREN;
        end
        else if(m_state_c == M_SE)begin
            case(s_state_c)
                S_CMD :tx_data <= CMD_SE;
                S_ADDR:tx_data <= wr_addr[23-cnt0*8 -:8];
                default:tx_data <= 0;
            endcase 
        end
        else if(m_state_c == M_RDSR)begin   //在读状态寄存器时，可以发一次命令，也可以连续发命令
            tx_data <= CMD_RDSR;
        end 
        else if(m_state_c == M_PP)begin 
            case(s_state_c)
                S_CMD :tx_data <= CMD_PP;
                S_ADDR:tx_data <= wr_addr[23-cnt0*8 -:8];
                S_DATA:tx_data <= wr_data + cnt0;
                default:tx_data <= 0;
            endcase 
        end 
    end

    always  @(posedge clk or negedge rst_n)begin
        if(rst_n==1'b0)begin
            tx_req <= 1'b0;
        end
        else if(s_idle2s_cmd)begin
            tx_req <= 1'b1;
        end
        else if(s_cmd2s_dela | s_addr2s_dela | s_data2s_dela)begin
            tx_req <= 1'b0;
        end
    end
//data    data_mask
    always @(posedge clk or negedge rst_n)begin 
        if(!rst_n)begin
            data <= 0;
            data_mask <= 0;
        end 
        else if(m_rdsr2m_idle & ~rdsr_wip)begin //PP completed
            data <= {"P","P",16'd0,4'd0,wr_data[7:4],4'd0,wr_data[3:0]};
            data_mask <= 6'b001100;
        end
        else if(m_rdsr2m_idle & rdsr_wip)begin //PP failed
            data <= {"P","P",8'd0,"ERR"};
            data_mask <= 6'b001000;
        end  
    end

//data_vld   ,
    always @(posedge clk or negedge rst_n)begin 
        if(!rst_n)begin
            data_vld <= 0;
        end 
        else begin 
            data_vld <= m_rdsr2m_idle;
        end 
    end

//输出
    assign tx_dout = tx_data;
    assign trans_req = tx_req;
    assign dout_vld = data_vld;
    assign dout_mask = data_mask;
    assign dout = data;

endmodule

