// https://docs.swiftylaun.ch/module/backendkit/notifkit-integration
import axios, { AxiosError } from "axios";
import { AxiosErrorType } from "..";
import { SFSymbol } from "./SFSymbol";
import { osAppApiKey, osAppID } from "../config";
import * as Analytics from "../AnalyticsKit/Analytics";

export type NotificationReadableData = {
  title: string;
  message: string;
  additionalData?: InAppNotificationAdditionalData;
};

// type to send additional data with the notification to route the notification to be shown as an in-app notification
type InAppNotificationAdditionalData = {
  inAppSymbol: SFSymbol;
  inAppColor: string; //in HEX
  inAppSize?: "normal" | "compact"; //defaults to normal
  inAppHaptics?: "success" | "warning" | "error"; // defaults to warning
};

// check out the docs if you want to add more params: https://documentation.onesignal.com/reference/push-channel-properties
// userID is an alias (external ID) and will be the same as the ID in firebase
export async function doesOneSignalUserExist(userID: string): Promise<boolean> {
  try {
    await axios.get(
      `https://api.onesignal.com/apps/${osAppID}/users/by/external_id/${userID}`,
      {
        headers: {
          Authorization: `Basic ${osAppApiKey}`,
          accept: "application/json",
          "content-type": "application/json",
        },
      },
    );
    return true;
  } catch (err) {
    const error = err as AxiosError<AxiosErrorType>;
    if (error?.code !== "404") {
      // 404 means user not found, other codes are errors
      console.error(error);
      Analytics.captureEvent({
        data: {
          eventType: "error",
          id: "os_user_exist_check",
          source: "notif",
          longDescription: `Error checking if OneSignal user exists: ${error.message}`,
        },
      });
    }
  }
  return false;
}

export async function sendNotificationToUserWithID({
  userID,
  data,
}: {
  userID: string;
  data: NotificationReadableData;
}) {
  // check if user exists
  const userExists = await doesOneSignalUserExist(userID);
  if (!userExists) throw new Error("User does not exist");

  try {
    await axios.post(
      `https://onesignal.com/api/v1/notifications`,
      {
        app_id: osAppID,
        target_channel: "push",
        include_aliases: { external_id: [userID] },
        contents: { en: data.message },
        headings: { en: data.title },
        data: data.additionalData,
      },
      {
        headers: {
          Authorization: `Basic ${osAppApiKey}`,
          accept: "application/json",
          "content-type": "application/json",
        },
      },
    );
  } catch (err) {
    const error = err as AxiosError<AxiosErrorType>;
    console.error(error);
    Analytics.captureEvent({
      data: {
        eventType: "error",
        id: "os_send_notification",
        source: "notif",
        longDescription: `Error calling OneSignal API to send Notification: ${error.message}`,
      },
    });
  }
}
