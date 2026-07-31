module ibex_mem_protocol_sva #(
  parameter bit CHECK_STORE_BE = 1'b0
) (
  input logic clk,
  input logic rst_n,
  input logic req,
  input logic gnt,
  input logic [31:0] addr,
  input logic we,
  input logic [3:0] be,
  input logic [31:0] wdata,
  input logic rvalid,
  input logic [31:0] rdata,
  input logic error
);
  timeunit 1ns;
  timeprecision 1ps;
  int unsigned pending_count;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) pending_count <= 0;
    else begin
      case ({req && gnt, rvalid})
        2'b10: pending_count <= pending_count + 1;
        2'b01: if (pending_count != 0) pending_count <= pending_count - 1;
        default: pending_count <= pending_count;
      endcase
    end
  end

  p_req_stable_until_grant: assert property (@(posedge clk) disable iff (!rst_n)
    req && !gnt |=> req && $stable({addr, we, be, wdata}))
    else $error("Memory request changed while waiting for grant");

  p_no_response_without_request: assert property (@(posedge clk) disable iff (!rst_n)
    rvalid |-> (pending_count != 0))
    else $error("Memory response without a pending granted request");

  p_response_eventually: assert property (@(posedge clk) disable iff (!rst_n)
    req && gnt |-> ##[1:64] rvalid)
    else $error("Memory response exceeded 64-cycle protocol bound");

  p_no_unknown_response: assert property (@(posedge clk) disable iff (!rst_n)
    rvalid |-> !$isunknown({rdata, error}))
    else $error("Memory response contains X/Z");

  p_reset_clears_tb_outputs: assert property (@(posedge clk)
    !rst_n |=> !gnt && !rvalid)
    else $error("Testbench memory outputs active during reset");

  if (CHECK_STORE_BE) begin : gen_store_be_checks
    p_store_be_legal: assert property (@(posedge clk) disable iff (!rst_n)
      req && gnt && we |->
        be inside {4'b0001, 4'b0010, 4'b0100, 4'b1000,
                   4'b0011, 4'b1100, 4'b1111})
      else $error("Store used an illegal byte-enable pattern");
  end
endmodule

module ibex_rvfi_protocol_sva (
  input logic clk,
  input logic rst_n,
  input logic valid,
  input logic [63:0] order
);
  timeunit 1ns;
  timeprecision 1ps;
  logic seen;
  logic [63:0] last_order;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      seen <= 1'b0;
      last_order <= '0;
    end else if (valid) begin
      if (seen) a_order_monotonic: assert (order == last_order + 1)
        else $error("RVFI order is not monotonic: last=%0d current=%0d", last_order, order);
      seen <= 1'b1;
      last_order <= order;
    end
  end
endmodule

bind ibex_tb_top ibex_mem_protocol_sva #(.CHECK_STORE_BE(1'b0)) u_imem_protocol_sva (
  .clk(clk), .rst_n(imem_if.rst_n), .req(imem_if.req), .gnt(imem_if.gnt),
  .addr(imem_if.addr), .we(imem_if.we), .be(imem_if.be), .wdata(imem_if.wdata),
  .rvalid(imem_if.rvalid), .rdata(imem_if.rdata), .error(imem_if.error)
);

bind ibex_tb_top ibex_mem_protocol_sva #(.CHECK_STORE_BE(1'b1)) u_dmem_protocol_sva (
  .clk(clk), .rst_n(dmem_if.rst_n), .req(dmem_if.req), .gnt(dmem_if.gnt),
  .addr(dmem_if.addr), .we(dmem_if.we), .be(dmem_if.be), .wdata(dmem_if.wdata),
  .rvalid(dmem_if.rvalid), .rdata(dmem_if.rdata), .error(dmem_if.error)
);

bind ibex_tb_top ibex_rvfi_protocol_sva u_rvfi_protocol_sva (
  .clk(clk), .rst_n(rvfi_if.rst_n), .valid(rvfi_if.valid), .order(rvfi_if.order)
);

