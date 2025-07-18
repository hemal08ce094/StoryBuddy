//
//  SignUpButtons.swift
//  FirebaseKit (Generated by SwiftyLaunch 2.0)
//  https://docs.swiftylaun.ch/module/authkit/email-sign-in-flow
//  https://docs.swiftylaun.ch/module/authkit/sign-in-with-apple-flow
//

import AnalyticsKit
import AuthenticationServices
import SharedKit
import SwiftUI
import UIKit

struct SignUpButtons: View {

	@EnvironmentObject var db: DB
	let shouldShowEmailSignUpScreen: () -> Void

	var body: some View {
		VStack(alignment: .leading) {

			AppleAuthButton()

			EmailSignUpButton(
				shouldShowEmailSignUpScreen: shouldShowEmailSignUpScreen
			)

			// You can also adapt this to show ToS and Privacy Policy with .webViewSheet
			Text(
				// need .init for markdown links to work
				.init(
					"By creating an Account you consent to our [ToS](\(Constants.AppData.termsOfServiceURL)) and [Privacy Policy](\(Constants.AppData.privacyPolicyURL))."
				)
			)
			.foregroundStyle(.secondary)
			.font(.caption)
			.padding(.top, 5)
			.frame(maxWidth: .infinity, alignment: currentPlatform == .phone ? .leading : .center)
		}
	}
}

struct AppleAuthButton: View {

	@Environment(\.colorScheme) private var colorScheme
	@EnvironmentObject var db: DB
	let onSuccessfulSignIn: (() -> Void)
	let showNotificationOnSuccessfulSignIn: Bool

	/// This is used to prevent multiple taps in a row, which may lead to errors
	@State private var isLoading: Bool

	init(
		showNotificationOnSuccessfulSignIn: Bool = true,
		onSuccessfulSignIn: @escaping () -> Void = {}
	) {
		self.showNotificationOnSuccessfulSignIn = showNotificationOnSuccessfulSignIn
		self.onSuccessfulSignIn = onSuccessfulSignIn
		self.isLoading = false
	}

	var body: some View {
		SignInWithAppleButton(
			.continue,
			onRequest: { request in
				isLoading = true
				db.handleSignInWithAppleRequest(request)
			},
			onCompletion: { complete in
				Task {
					await tryFunctionOtherwiseShowInAppNotification(
						fallbackNotificationContent: .init(
							title: "Sign In Error", message: "Couldn't Sign in with Apple")
					) {
						isLoading = false
						if try await db.handleSignInWithAppleCompletion(complete) {
							onSuccessfulSignIn()
							if showNotificationOnSuccessfulSignIn {
								showInAppNotification(
									.success,
									content: .init(
										title: "Successfully Signed In", message: "Enjoy!"
									), size: .compact)
							}
						}

					}
				}
			}
		)
		.signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
		.frame(height: 50)
		.frame(maxWidth: .infinity)
		.clipShape(RoundedRectangle(cornerRadius: 50, style: .continuous))
		.disabled(isLoading)
		.onAppear {
			// Doesnt matter that much, can be safely deleted. Just to suppress the log warning about SignInWithApple Button Layout Constraints.
			#if DEBUG
				UserDefaults.standard.set(false, forKey: "_UIConstraintBasedLayoutLogUnsatisfiable")
			#endif
		}
	}
}

struct EmailSignUpButton: View {

	let shouldShowEmailSignUpScreen: () -> Void

	var body: some View {
		Button(
			action: {
				shouldShowEmailSignUpScreen()
			},
			label: {
				HStack {
					Image(systemName: "envelope")
						.fontWeight(.semibold)
					Text("Sign Up using Email")
				}
			}
		)
		.buttonStyle(.secondary())
		.captureTaps("sign_up_email_btn", fromView: "SignUpButtons", relevancy: .high)
	}
}

#Preview {
	SignUpButtons(shouldShowEmailSignUpScreen: {})
		.padding()
}
