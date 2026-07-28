import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  mockAuthenticatedSessionFlags,
  mockDrawingsList,
} from "../../helpers/mock-api.js";

test("switching_from_anonymous_to_google", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "switching_from_anonymous_to_google",
    testTitle: testInfo.title,
  });

  await recorder.step("Start with logged-out draw page offering Google sign-in");
  await mockAuthenticatedSessionFlags(page, {
    loggedIn: false,
    google: true,
    github: false,
  });
  await page.goto("/draw");
  await expect(page.getByRole("link", { name: "Sign-in with Google" })).toBeVisible();

  await recorder.step("After Google sign-in, return authenticated session with only Google drawings");
  await mockAuthenticatedSessionFlags(page, {
    loggedIn: true,
    google: true,
    github: false,
  });
  await mockDrawingsList(page, {
    blobs: [
      {
        pathname: "drawings/google-library-item.jpg",
        uploadedAt: "2026-07-28T00:00:00.000Z",
        customMetadata: {
          description: "Google library item",
          userProvider: "google",
          userId: "google-user-1",
          userName: "Google User",
          userAvatar: "https://example.com/google-user.png",
          userUrl: "https://google.example/user/google-user-1",
          url: "https://cdn.example.com/drawings/google-library-item.jpg",
        },
      },
    ],
    cursor: null,
    hasMore: false,
  });

  await recorder.step("Simulate navigation after Google auth and verify anonymous drawing is not shown");
  await page.goto("/");
  await expect(page.getByRole("img", { name: "Google library item" })).toBeVisible();
  await expect(page.getByText("Google User")).toBeVisible();
  await expect(page.getByText("Anonymous Artist")).toHaveCount(0);
  await expect(page.getByText("Anonymous drawing")).toHaveCount(0);

  console.log("CODEVALID_TEST_ASSERTION_OK:switching_from_anonymous_to_google");
  await recorder.save(testInfo);
});
