export const handler = async (event) => {
  for (const record of event.Records) {
    const { userId, channel, template, data } = JSON.parse(record.body);

    console.log(
      JSON.stringify({
        level: "info",
        message: "processing notification",
        messageId: record.messageId,
        userId,
        channel,
        template,
      }),
    );

    await deliver({ channel, userId, template, data });

    console.log(
      JSON.stringify({
        level: "info",
        message: "notification sent",
        messageId: record.messageId,
        userId,
        channel,
      }),
    );
  }
};

// Placeholder for the real provider call (SES, SNS, FCM, Twilio, etc).
// The 50ms sleep simulates network latency so the logs reflect realistic timing.
const deliver = async ({ channel, userId, template, data }) => {
  await new Promise((resolve) => setTimeout(resolve, 50));
  console.log(
    JSON.stringify({
      level: "info",
      message: `simulated ${channel} delivery`,
      userId,
      template,
      data,
    }),
  );
};
