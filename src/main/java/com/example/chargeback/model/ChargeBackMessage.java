package com.example.chargeback.model;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ChargebackMessage {
    
    @JsonProperty("transaction_id")
    private String transactionId;
    
    @JsonProperty("chargeback_id")
    private String chargebackId;
    
    @JsonProperty("amount")
    private BigDecimal amount;
    
    @JsonProperty("currency")
    private String currency;
    
    @JsonProperty("merchant_id")
    private String merchantId;
    
    @JsonProperty("reason_code")
    private String reasonCode;
    
    @JsonProperty("timestamp")
    private LocalDateTime timestamp;
    
    @JsonProperty("customer_id")
    private String customerId;
    
    @JsonProperty("card_last_four")
    private String cardLastFour;
    
    @JsonProperty("status")
    private String status;
}
