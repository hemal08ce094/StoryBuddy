// https://docs.swiftylaun.ch/module/backendkit/analyticskit-integration
import { PostHog } from "posthog-node";
import { postHogAPIKey, postHogHost } from "../config";
import { logger } from "firebase-functions"; // if you need to log something, use logger.info("message") instead of console.log("message"), so it shows up in the Google Cloud logs

type EventData = {
  eventType: "info" | "error" | "success";
  id: string; // id to recognize the event
  longDescription?: string; // optional, more detailed description of the event
  // source of the event
  source: "general" | "auth" | "db" | "analytics" | "iap" | "notif";
  relevancy?: "low" | "medium" | "high"; // info defaults to medium, error to high
};

export async function captureEvent({
  data,
  fromUserID,
}: {
  data: EventData;
  fromUserID?: string;
}) {
  const client = new PostHog(postHogAPIKey, { host: postHogHost });
  const { eventType, id, longDescription, source, relevancy } = data;
  logger.info(
    `[ANALYTICS] Captured ${eventType} event '${id}' of type '${source}': ${
      longDescription || "No description"
    }`,
  );

  const properties = {
    relevancy: relevancy || (eventType === "error" ? "high" : "medium"),
    source,
    longDescription,
    endpoint_source: "backend",
  };

  client.capture({
    distinctId: fromUserID || "NO_USER_ID", // if an action is the result of a user interaction, the user id should be passed, otherwise it will be "NO_USER_ID"
    event: `${eventType}_${id}`,
    properties: properties,
  });
}
