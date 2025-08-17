`timescale 1ns / 1ps    

//typedef struct packed {
//	logic       valid;  
//	logic [4:0] idx;       	//id of the register
//} a_reg_t;				   	//architectural register

//typedef struct packed {
//	logic       valid;
//	a_reg_t  	rd;		   	//only valid if rd used
//	a_reg_t 	rs1;	   	//only valid if rs1 used
//	a_reg_t 	rs2;	   	//only valid if rs2 used
//	logic       is_branch;	//bonus 
//} dinstr_t;	                //decoded instruction


//typedef struct packed {
//	logic       valid;  
//	logic [5:0] idx;    	//id of the new register
//	logic       ready;  	// 
//} p_reg_t;					//physical register

//typedef struct packed {
//	logic       valid;
//	p_reg_t   	rd;
//	p_reg_t   	rs1;
//	p_reg_t   	rs2;
//} rinstr_t;					//renamed instruction

//typedef struct packed {
//	logic valid;
//	logic hit;
//} br_result_t;

//renamed instruction  
//import types_pkg::a_reg_t;
//import types_pkg::dinstr_t;
//import types_pkg::p_reg_t;
//import types_pkg::rinstr_t;
//import types_pkg::br_result_t;

//typedef struct packed {
//	logic       valid;  
//	logic [4:0] idx;       	//id of the register
//} a_reg_t;				   	//architectural register

//typedef struct packed {
//	logic       valid;
//	a_reg_t  	rd;		   	//only valid if rd used
//	a_reg_t 	rs1;	   	//only valid if rs1 used
//	a_reg_t 	rs2;	   	//only valid if rs2 used
//	logic       is_branch;	//bonus 
//} dinstr_t;	                //decoded instruction


//typedef struct packed {
//	logic       valid;  
//	logic [5:0] idx;    	//id of the new register
//	logic       ready;  	// 
//} p_reg_t;					//physical register

//typedef struct packed {
//	logic       valid;
//	p_reg_t   	rd;
//	p_reg_t   	rs1;
//	p_reg_t   	rs2;
//} rinstr_t;					//renamed instruction

 
 
 
 

// sýfýrlamada i ata 
module NewRenamefile (
    input  logic       clk_i,                 // Saat sinyali
    input  logic       rst_ni,                // Aktif-düþük sýfýrlama sinyali
    input  logic       StallD,  
    input  br_result_t br_result_i,           // br_result_i.valid: Dallanma sonucunun geçerli olup olmadýðýný belirtir
                                              // br_result_i.hit: Dallanma tahmininin doðru olup olmadýðýný belirtir

    input  p_reg_t     p_commit_i,            // p_commit_i.valid: Commit iþleminin geçerli olup olmadýðýný belirtir
                                              // p_commit_i.idx: Fiziksel kaydýn 6-bit indeksi
                                              // p_commit_i.ready: Fiziksel kaydýn hazýr olup olmadýðýný belirtir
    input [5:0] prev_prf_idx_i ,              // eski indexi tutar busy table güncellemek için gereklimi 
    input prev_prf_idx_valid_i,
    input  dinstr_t    dinstr_i,              // dinstr_i.valid: Talimatýn geçerli olup olmadýðýný belirtir
                                              // dinstr_i.rd.valid: Hedef mimari kaydýn kullanýlýp kullanýlmadýðýný belirtir
                                              // dinstr_i.rd.idx: Hedef mimari kaydýn 5-bit indeksi
                                              // dinstr_i.rs1.valid: 1. kaynak mimari kaydýn kullanýlýp kullanýlmadýðýný belirtir
                                              // dinstr_i.rs1.idx: 1. kaynak mimari kaydýn 5-bit indeksi
                                              // dinstr_i.rs2.valid: 2. kaynak mimari kaydýn kullanýlýp kullanýlmadýðýný belirtir
                                              // dinstr_i.rs2.idx: 2. kaynak mimari kaydýn 5-bit indeksi
                                              // dinstr_i.is_branch: Talimatýn dallanma talimatý olup olmadýðýný belirtir
    input commic_spec,
    output rinstr_t    rinstr_o,              // rinstr_o.valid: Yeniden adlandýrýlmýþ talimatýn geçerli olup olmadýðýný belirtir
                                              // rinstr_o.rd.valid: Hedef fiziksel kaydýn geçerli olup olmadýðýný belirtir
                                              // rinstr_o.rd.idx: Hedef fiziksel kaydýn 6-bit indeksi
                                              // rinstr_o.rd.ready: Hedef fiziksel kaydýn hazýr olup olmadýðýný belirtir
                                              // rinstr_o.rs1.valid: 1. kaynak fiziksel kaydýn geçerli olup olmadýðýný belirtir
                                              // rinstr_o.rs1.idx: 1. kaynak fiziksel kaydýn 6-bit indeksi
                                              // rinstr_o.rs1.ready: 1. kaynak fiziksel kaydýn hazýr olup olmadýðýný belirtir
                                              // rinstr_o.rs2.valid: 2. kaynak fiziksel kaydýn geçerli olup olmadýðýný belirtir
                                              // rinstr_o.rs2.idx: 2. kaynak fiziksel kaydýn 6-bit indeksi
                                              // rinstr_o.rs2.ready: 2. kaynak fiziksel kaydýn hazýr olup olmadýðýný belirtir
    input logic ready1,ready2,ready3,
    input logic ready1_spec,ready2_spec,ready3_spec,         
    input logic [5:0] ready1_addr,ready2_addr,ready3_addr,   
   
    output logic [5:0] prev_prf_idx_o,
    output logic       prev_prf_idx_valid_o,
    output logic       branch_active,
    output logic       rn_full_o     
);
    logic [5:0] RenameMem [0:31] ;  
    logic Freelist [0:63];
    logic BusyTable [0:63];
    logic [$clog2(64)-1:0] available_register;
    logic no_free_reg;
    
    logic [5:0] Checkpoint_RenameMem [0:31] ;  
    logic       Checkpoint_Freelist [0:63];
    logic       Checkpoint_BusyTable [0:63];
    logic       Checkpoint_Active;
    
    always_comb begin    
        // Default assignments
        rinstr_o.valid = 1'b0;
        rinstr_o.rd.valid = 1'b0;
        rinstr_o.rd.idx = 6'b0;
        rinstr_o.rd.ready = 1'b0;
        rinstr_o.rs1.valid = 1'b0;
        rinstr_o.rs1.idx = 6'b0;
        rinstr_o.rs1.ready = 1'b0;
        rinstr_o.rs2.valid = 1'b0;
        rinstr_o.rs2.idx = 6'b0;
        rinstr_o.rs2.ready = 1'b0;
        
        prev_prf_idx_o = 6'b0;
        prev_prf_idx_valid_o = 1'b0;
        // Process valid instructions
        if (dinstr_i.valid && !no_free_reg && !StallD ) begin
            rinstr_o.valid = 1'b1;
            
           
            if (dinstr_i.rd.valid) begin
                rinstr_o.rd.valid = 1'b1;
                if (dinstr_i.rd.idx == 5'd0) begin 
                  
                    rinstr_o.rd.idx = 6'd0;
                    rinstr_o.rd.ready = 1'b1;
                    prev_prf_idx_o= RenameMem[dinstr_i.rd.idx];
                    prev_prf_idx_valid_o= RenameMem[dinstr_i.rd.idx]==6'd0 ? 1'b0 : 1'b1;
                end else begin
                    prev_prf_idx_o = RenameMem[dinstr_i.rd.idx];
                    prev_prf_idx_valid_o = RenameMem[dinstr_i.rd.idx]==6'd0 ? 1'b0 : 1'b1;
                    // Allocate new physical register
                    rinstr_o.rd.idx = available_register;
                    rinstr_o.rd.ready = 1'b0; // New allocation is not ready ?
                end
            end
            
            // Handle source register 1
            if (dinstr_i.rs1.valid) begin
                rinstr_o.rs1.valid = 1'b1;
                if (dinstr_i.rs1.idx == 5'd0) begin
                    rinstr_o.rs1.idx = 6'd0;
                    rinstr_o.rs1.ready = 1'b1;
                end else begin 
                    rinstr_o.rs1.idx = RenameMem[dinstr_i.rs1.idx];
                    // Check if register is ready (not busy or being committed this cycle)
                    rinstr_o.rs1.ready = (~BusyTable[RenameMem[dinstr_i.rs1.idx]]) ||
              (ready1 && ready1_addr == RenameMem[dinstr_i.rs1.idx]) || (ready2 && ready2_addr == RenameMem[dinstr_i.rs1.idx]) ||
              (ready3 && ready3_addr == RenameMem[dinstr_i.rs1.idx])  ;
                    
//        ||    (p_commit_i.valid && p_commit_i.ready && p_commit_i.idx == RenameMem[dinstr_i.rs1.idx]);
                end
            end else begin
                 rinstr_o.rs1.valid = 1'b0;
                 rinstr_o.rs1.idx = 6'd0;
                 rinstr_o.rs1.ready = 1'b0;
            end
            // Handle source register 2
            if (dinstr_i.rs2.valid) begin
                rinstr_o.rs2.valid = 1'b1;
                if (dinstr_i.rs2.idx == 5'd0) begin
                    
                    rinstr_o.rs2.idx = 6'd0;
                    rinstr_o.rs2.ready = 1'b1;
                end else begin 
                    // Map architectural register to physical register
                    rinstr_o.rs2.idx = RenameMem[dinstr_i.rs2.idx];
                    rinstr_o.rs2.ready = (~BusyTable[RenameMem[dinstr_i.rs2.idx]]) ||
                    (ready1 && ready1_addr == RenameMem[dinstr_i.rs2.idx]) || (ready2 && ready2_addr == RenameMem[dinstr_i.rs2.idx]) 
                    || (ready3 && ready3_addr == RenameMem[dinstr_i.rs2.idx]) ;
                                        /*(~BusyTable[RenameMem[dinstr_i.rs2.idx]]) || 
                                        (p_commit_i.valid && p_commit_i.ready && 
                                         p_commit_i.idx == RenameMem[dinstr_i.rs2.idx]);*/
                end
            end else begin
                 rinstr_o.rs2.valid = '0;
                 rinstr_o.rs2.idx   = '0;
                 rinstr_o.rs2.ready = '0;
            end
        end
    end
    
always_ff @(posedge clk_i or negedge rst_ni ) begin
    if(!rst_ni)begin
           Checkpoint_Active <= 1'b0;

//        for(int i=0;i<32;i++)begin
//           RenameMem[i] <= 6'b0 ; // i de atanabilir tercih etmedim
////            RenameMem[i] <= i[5:0] ;
//        end
//            Freelist[0] <=1'b0;
//            BusyTable[0] <= 1'b0;
//        for(int i=1;i<64;i++)begin
//            Freelist[i]<=1'b1;
//            BusyTable[i]<=1'b0;
//        end
//        Checkpoint_Active <= 1'b0;
//    end
          for(int i=0;i<32;i++)begin
            RenameMem[i] <= i[5:0] ;
            Freelist[i] <= 1'b0;
            BusyTable[i] <= 1'b0;
            end
          for(int i=32;i<64;i++)begin
            Freelist[i] <= 1'b1;
            BusyTable[i] <= 1'b0;
            end          
          for (int i = 0; i < 32; i++) begin
              Checkpoint_RenameMem[i] <= 6'b0;
            end
          for (int i = 0; i < 64; i++) begin
              Checkpoint_Freelist[i] <= 1'b0;
              Checkpoint_BusyTable[i] <= 1'b0;
            end
    end      
    else begin  
    
        if(dinstr_i.valid && (dinstr_i.is_branch || dinstr_i.is_jump)&& !Checkpoint_Active && !StallD) begin
            Checkpoint_Active<=1'b1;
            for(int i=0; i<32 ; i++)begin
                Checkpoint_RenameMem[i]<=RenameMem[i];
            end
            for( int i = 0 ; i<64;i++)begin
                Checkpoint_Freelist[i] <= Freelist[i];
                Checkpoint_BusyTable[i]<= BusyTable[i]; 
            end
        end
        //  // br_result_i.valid: Dallanma sonucunun geçerli olup olmadýðýný belirtir
             // br_result_i.hit: Dallanma tahmininin doðru olup olmadýðýný belirtir
        if(br_result_i.valid && Checkpoint_Active)begin
            Checkpoint_Active<=1'b0;
            if(!br_result_i.hit)begin
                for(int i=0; i<32 ; i++)begin
                    RenameMem[i]<=Checkpoint_RenameMem[i];
                end
                for( int i = 0 ; i<64;i++)begin
                   Freelist[i]<=Checkpoint_Freelist[i] ;
                   BusyTable[i]<=  Checkpoint_BusyTable[i] ; 
                end
            end
//           if(br_result_i.hit) begin
           
//           end
        end
        
        if(ready1)BusyTable[ready1_addr] <= 1'b0; //NOT BUSY                                                      
        if(ready2)BusyTable[ready2_addr] <= 1'b0; //NOT BUSY                                                       
        if(ready3)BusyTable[ready3_addr] <= 1'b0; //NOT BUSY   
        if(Checkpoint_Active)begin
          if(ready1 && !ready1_spec)  Checkpoint_BusyTable[ready1_addr]<=1'b0;
          if(ready2 && !ready2_spec)  Checkpoint_BusyTable[ready2_addr]<=1'b0;
          if(ready3 && !ready3_spec)  Checkpoint_BusyTable[ready3_addr]<=1'b0;
        end                                                    
         
//         if(!commic_spec && Checkpoint_Active) // BU IF GEREKSIZ CUNKU SPEC COMMIT YAPILMAZ BUNU KONTROL ET  
//           Checkpoint_BusyTable[p_commit_i.idx]<=1'b0;                                                       
                         
        if(p_commit_i.valid && p_commit_i.ready)begin
            if(prev_prf_idx_valid_i && prev_prf_idx_i != 6'd0)begin
                Freelist[prev_prf_idx_i]<=1'b1; //FREE
                if(!commic_spec && Checkpoint_Active)
                    Checkpoint_Freelist[prev_prf_idx_i]<=1'b1;
            end
//            BusyTable[p_commit_i.idx] <= 1'b0; //NOT BUSY
//            if(!commic_spec && Checkpoint_Active) // BU IF GEREKSIZ CUNKU SPEC COMMIT YAPILMAZ BUNU KONTROL ET
//              Checkpoint_BusyTable[p_commit_i.idx]<=1'b0;
        end    
       
        if(dinstr_i.valid && !no_free_reg && !StallD && !(br_result_i.valid && !br_result_i.hit))begin
            if(dinstr_i.rd.valid && dinstr_i.rd.idx != 5'd0)begin
             RenameMem[dinstr_i.rd.idx] <= available_register;
             Freelist[available_register]<=1'b0; //NOT FREE
             BusyTable[available_register] <= 1'b1; // BUSY
             if(dinstr_i.is_branch || dinstr_i.is_jump) begin
              Checkpoint_RenameMem[dinstr_i.rd.idx]<=available_register; 
              Checkpoint_Freelist[available_register] <=1'b0;
              Checkpoint_BusyTable[available_register]<=1'b1;   
              end 
            end
        end
      end
end 

        logic [63:0] freelistavaible ;
        always_comb begin
            for (int i = 0; i < 64; i++) begin
                freelistavaible[i] = Freelist[63-i];
            end
        end   
        LZC #(.W_IN(64)) lzc_inst1 (
               .in(freelistavaible),
               .out(available_register[5:0]),
               .overflow(no_free_reg)
        );

        assign rn_full_o= no_free_reg;
        assign branch_active = Checkpoint_Active || dinstr_i.is_branch || dinstr_i.is_jump; // checkpoint active ken 2. bir branch almýcam 
        // Daha sonra yapýlcaklar listesi
        // NESTED BRANCH SUPPORT EKLEMEK
        // LSU CACHE EKLEMEK 
           
endmodule
