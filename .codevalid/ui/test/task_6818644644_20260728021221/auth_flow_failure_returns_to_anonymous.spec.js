import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  mockAuthenticatedSessionFlags,
  mockAuthFailureFallbackToAnonymous,
  mockDrawingUploadSuccess,
  mockDrawingsList,
  drawOnCanvas,
} from "../../helpers/mock-api.js";

test("auth_flow_failure_returns_to_anonymous", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "auth_flow_failure_returns_to_anonymous",
    testTitle: testInfo.title,
  });

  await recorder.step("Start logged out with Google sign-in available");
  await mockAuthenticatedSessionFlags(page, {
    loggedIn: false,
    google: true,
    github: false,
  });
  await mockAuthFailureFallbackToAnonymous(page, { provider: "google" });
  await page.goto("/draw");
  await expect(page.getByRole("link", { name: "Sign-in with Google" })).toBeVisible();

  await recorder.step("Trigger failed Google auth and land back on draw page as anonymous session");
  await page.getByRole("link", { name: "Sign-in with Google" }).click();
  await expect(page).toHaveURL(/\/draw$/);
  await expect(page.getByRole("button", { name: "Share my drawing" })).toBeVisible();

  await recorder.step("Mock anonymous upload and gallery to verify features remain usable");
  await mockDrawingUploadSuccess(page, {
    pathname: "drawings/anonymous-after-failed-auth.jpg",
    customMetadata: {
      description: "Anonymous after failed auth",
      userProvider: "anonymous",
      userId: "anon-local-2",
      userName: "Anonymous Artist",
      userAvatar: "",
      userUrl: "",
      url: "https://cdn.example.com/drawings/anonymous-after-failed-auth.jpg",
    },
  });
  await mockDrawingsList(page, {
    blobs: [
      {
        pathname: "drawings/anonymous-after-failed-auth.jpg",
        uploadedAt: "2026-07-28T00:00:00.000Z",
        customMetadata: {
          description: "Anonymous after failed auth",
          userProvider: "anonymous",
          userId: "anon-local-2",
          userName: "Anonymous Artist",
          userAvatar: "",
          userUrl: "",
          url: "https://cdn.example.com/drawings/anonymous-after-failed-auth.jpg",
        },
      },
    ],
    cursor: null,
    hasMore: false,
  });

  await recorder.step("Create and share a drawing to confirm anonymous fallback remains functional");
  await drawOnCanvas(page);
  await page.getByRole("button", { name: "Share my drawing" }).click();
  await expect(page).toHaveURL(/\/$/);
  await expect(page.getByRole("img", { name: "Anonymous after failed auth" })).toBeVisible();
  await expect(page.getByText("Anonymous Artist")).toBeVisible();

  console.log("CODEVALID_TEST_ASSERTION_OK:auth_flow_failure_returns_to_anonymous");
  await recorder.save(testInfo);
});
