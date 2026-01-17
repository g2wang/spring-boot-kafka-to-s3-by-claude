package com.example.chargeback.config;

import com.amazonaws.auth.AWSCredentialsProvider;
import com.amazonaws.auth.DefaultAWSCredentialsProviderChain;
import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.AmazonS3ClientBuilder;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class AwsS3Config {

    @Value("${aws.region:us-east-1}")
    private String region;

    @Bean
    public AWSCredentialsProvider awsCredentialsProvider() {
        return DefaultAWSCredentialsProviderChain.getInstance();
    }

    @Bean
    public AmazonS3 amazonS3(AWSCredentialsProvider credentialsProvider) {
        return AmazonS3ClientBuilder
            .standard()
            .withCredentials(credentialsProvider)
            .withRegion(region)
            .build();
    }
}
