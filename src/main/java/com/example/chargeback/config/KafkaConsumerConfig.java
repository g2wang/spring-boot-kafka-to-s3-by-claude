package com.example.chargeback.config;

import com.example.chargeback.model.ChargebackMessage;
import lombok.extern.slf4j.Slf4j;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.common.serialization.StringDeserializer;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.annotation.EnableKafka;
import org.springframework.kafka.config.ConcurrentKafkaListenerContainerFactory;
import org.springframework.kafka.core.ConsumerFactory;
import org.springframework.kafka.core.DefaultKafkaConsumerFactory;
import org.springframework.kafka.listener.DefaultErrorHandler;
import org.springframework.kafka.support.serializer.ErrorHandlingDeserializer;
import org.springframework.kafka.support.serializer.JsonDeserializer;
import org.springframework.kafka.support.serializer.DeserializationException;
import org.springframework.util.backoff.FixedBackOff;

import java.util.HashMap;
import java.util.Map;

@Slf4j
@EnableKafka
@Configuration
public class KafkaConsumerConfig {

    @Value("${spring.kafka.bootstrap-servers}")
    private String bootstrapServers;

    @Value("${spring.kafka.consumer.group-id}")
    private String groupId;

    @Bean
    public ConsumerFactory<String, ChargebackMessage> consumerFactory() {
        Map<String, Object> config = new HashMap<>();
        config.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        config.put(ConsumerConfig.GROUP_ID_CONFIG, groupId);
        
        // Use ErrorHandlingDeserializer for key
        config.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, ErrorHandlingDeserializer.class);
        config.put(ErrorHandlingDeserializer.KEY_DESERIALIZER_CLASS, StringDeserializer.class);
        
        // Use ErrorHandlingDeserializer for value
        config.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, ErrorHandlingDeserializer.class);
        config.put(ErrorHandlingDeserializer.VALUE_DESERIALIZER_CLASS, JsonDeserializer.class);
        config.put(JsonDeserializer.TRUSTED_PACKAGES, "*");
        config.put(JsonDeserializer.VALUE_DEFAULT_TYPE, ChargebackMessage.class);
        config.put(JsonDeserializer.USE_TYPE_INFO_HEADERS, false);
        
        config.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");
        config.put(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, false);
        
        return new DefaultKafkaConsumerFactory<>(config);
    }

    @Bean
    public ConcurrentKafkaListenerContainerFactory<String, ChargebackMessage> kafkaListenerContainerFactory() {
        ConcurrentKafkaListenerContainerFactory<String, ChargebackMessage> factory = 
            new ConcurrentKafkaListenerContainerFactory<>();
        factory.setConsumerFactory(consumerFactory());
        factory.getContainerProperties().setAckMode(
            org.springframework.kafka.listener.ContainerProperties.AckMode.MANUAL);
        
        // Configure error handler to handle deserialization exceptions
        // DefaultErrorHandler will automatically seek past failed records
        // DeserializationException is treated as fatal (not retryable) by default
        DefaultErrorHandler errorHandler = new DefaultErrorHandler(
            (record, ex) -> {
                Throwable cause = ex.getCause();
                if (cause instanceof DeserializationException) {
                    log.error("Failed to deserialize message from topic: {}, partition: {}, offset: {}. Skipping malformed record.", 
                        record.topic(), record.partition(), record.offset(), cause);
                } else {
                    log.error("Failed to process message from topic: {}, partition: {}, offset: {}. Skipping record.", 
                        record.topic(), record.partition(), record.offset(), ex);
                }
            },
            new FixedBackOff(0L, 0L) // No retry, just log and skip
        );
        // Ensure DeserializationException is treated as not retryable (fatal)
        // This causes the error handler to immediately seek past the failed record
        errorHandler.addNotRetryableExceptions(
            DeserializationException.class,
            org.apache.kafka.common.errors.SerializationException.class
        );
        factory.setCommonErrorHandler(errorHandler);
        
        return factory;
    }
}
