// https://docs.swiftylaun.ch/module/backendkit/inapppurchasekit-integration
import axios, { AxiosError } from "axios";
import { AxiosErrorType } from "..";
import { rcApiKey } from "../config";
import * as Analytics from "../AnalyticsKit/Analytics";

// will check if currently logged in user has premium
// www.revenuecat.com/docs/api-v1
export async function doesUserHavePremium(userID: string): Promise<boolean> {
  Analytics.captureEvent({
    data: {
      eventType: "info",
      id: "check_if_user_has_premium",
      source: "iap",
      longDescription: `UserID: ${userID}`,
    },
  });

  let gotPremium = false;

  try {
    let customerData = await axios.get(
      `https://api.revenuecat.com/v1/subscribers/${userID}`,
      {
        headers: {
          Authorization: `Bearer ${rcApiKey}`,
        },
      },
    );

    //We check if the expiration date is in the future and if it is, we know the user has premium
    let expirationDateAny =
      customerData.data?.subscriber?.entitlements["Premium Access"]
        ?.expires_date;

    console.log("Received expires_date: ", expirationDateAny);

    if (expirationDateAny) {
      let expirationDate = new Date(expirationDateAny);
      let now = new Date();

      console.log("Parsed expires_date: ", expirationDate);
      console.log("Now: ", now);
      console.log("ExpirationDate > now: ", expirationDate > now);

      if (expirationDate > now) {
        gotPremium = true;
      }
    }
  } catch (err) {
    const error = err as AxiosError<AxiosErrorType>;
    if (error?.code !== "404") {
      // 404 means user not found, other codes are errors
      console.error(error);
      Analytics.captureEvent({
        data: {
          eventType: "error",
          id: "rc_user_sub_check",
          source: "iap",
          longDescription: `Error checking RevenueCat User Subscription Status: ${error.message}`,
        },
      });
    }
  }

  console.log(`User ${userID} has premium: ${gotPremium}`);

  return gotPremium;
}
