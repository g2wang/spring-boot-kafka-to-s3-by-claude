package com.example.chargeback.service;

import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.model.ObjectMetadata;
import com.amazonaws.services.s3.model.PutObjectRequest;
import com.example.chargeback.model.ChargebackMessage;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.io.ByteArrayInputStream;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.UUID;

@Slf4j
@Service
public class S3Service {

    private final AmazonS3 amazonS3;
    private final ObjectMapper objectMapper;
    
    @Value("${aws.s3.bucket-name:chargebacks}")
    private String bucketName;

    public S3Service(AmazonS3 amazonS3) {
        this.amazonS3 = amazonS3;
        this.objectMapper = new ObjectMapper();
        this.objectMapper.registerModule(new JavaTimeModule());
    }

    public void writeToS3(ChargebackMessage message) {
        try {
            String s3Key = generateS3Key(message);
            String jsonContent = objectMapper.writeValueAsString(message);
            
            byte[] contentBytes = jsonContent.getBytes();
            ByteArrayInputStream inputStream = new ByteArrayInputStream(contentBytes);
            
            ObjectMetadata metadata = new ObjectMetadata();
            metadata.setContentLength(contentBytes.length);
            metadata.setContentType("application/json");
            
            PutObjectRequest putObjectRequest = new PutObjectRequest(
                bucketName,
                s3Key,
                inputStream,
                metadata
            );
            
            amazonS3.putObject(putObjectRequest);
            log.info("Successfully wrote chargeback {} to S3: {}", 
                message.getChargebackId(), s3Key);
            
        } catch (Exception e) {
            log.error("Failed to write chargeback {} to S3", 
                message.getChargebackId(), e);
            throw new RuntimeException("Failed to write to S3", e);
        }
    }

    private String generateS3Key(ChargebackMessage message) {
        LocalDateTime timestamp = message.getTimestamp() != null 
            ? message.getTimestamp() 
            : LocalDateTime.now();
        
        String year = timestamp.format(DateTimeFormatter.ofPattern("yyyy"));
        String month = timestamp.format(DateTimeFormatter.ofPattern("MM"));
        String day = timestamp.format(DateTimeFormatter.ofPattern("dd"));
        String hour = timestamp.format(DateTimeFormatter.ofPattern("HH"));
        
        String filename = String.format("%s_%s.json",
            message.getChargebackId(),
            UUID.randomUUID().toString().substring(0, 8)
        );
        
        return String.format("year=%s/month=%s/day=%s/hour=%s/%s",
            year, month, day, hour, filename);
    }
}
