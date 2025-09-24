//
//  AWSEndUserMessaing.swift
//  Rangley
//
//  Created by Anthony Guzzardo on 9/24/25.
//

import { EndUserMessagingSMSClient, SendTextMessageCommand } from "@aws-sdk/client-end-user-messaging-sms";

const client = new EndUserMessagingSMSClient({ region: "us-east-1" });

const sendVerificationCode = async (phoneNumber, code) => {
  const params = {
    DestinationPhoneNumber: phoneNumber,
    OriginationIdentity: "your-phone-pool-id", // Your phone pool ID
    MessageBody: `Your Rangley verification code is: ${code}`,
    MessageType: "TRANSACTIONAL"
  };
  
  return await client.send(new SendTextMessageCommand(params));
};
