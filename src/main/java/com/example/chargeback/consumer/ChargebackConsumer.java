package com.example.chargeback.consumer;

import com.example.chargeback.model.ChargebackMessage;
import com.example.chargeback.service.S3Service;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.kafka.support.KafkaHeaders;
import org.springframework.messaging.handler.annotation.Header;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class ChargebackConsumer {

    private final S3Service s3Service;

    @KafkaListener(
        topics = "${kafka.topic.chargebacks:chargebacks}",
        groupId = "${spring.kafka.consumer.group-id}",
        containerFactory = "kafkaListenerContainerFactory"
    )
    public void consume(
        @Payload ChargebackMessage message,
        @Header(KafkaHeaders.RECEIVED_PARTITION) int partition,
        @Header(KafkaHeaders.OFFSET) long offset,
        Acknowledgment acknowledgment
    ) {
        try {
            log.info("Received chargeback message: ID={}, TransactionID={}, Partition={}, Offset={}",
                message.getChargebackId(),
                message.getTransactionId(),
                partition,
                offset
            );

            // Transform and write to S3
            s3Service.writeToS3(message);

            // Manually acknowledge after successful processing
            acknowledgment.acknowledge();
            
            log.info("Successfully processed chargeback: {}", message.getChargebackId());
            
        } catch (Exception e) {
            log.error("Error processing chargeback message: {}", message.getChargebackId(), e);
            // Don't acknowledge on failure - message will be reprocessed
            throw new RuntimeException("Failed to process message", e);
        }
    }
}
