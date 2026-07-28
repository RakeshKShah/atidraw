import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  mockGoogleAuthenticatedSession,
  mockAnonymousOnlySession,
  mockDrawingsList,
} from "../../helpers/mock-api.js";

test("switching_from_google_to_anonymous", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "switching_from_google_to_anonymous",
    testTitle: testInfo.title,
  });

  await recorder.step("Open gallery with Google-authenticated drawing present");
  await mockGoogleAuthenticatedSession(page);
  await mockDrawingsList(page, {
    blobs: [
      {
        pathname: "drawings/google-saved.jpg",
        uploadedAt: "2026-07-28T00:00:00.000Z",
        customMetadata: {
          description: "Google saved drawing",
          userProvider: "google",
          userId: "google-user-1",
          userName: "Google User",
          userAvatar: "https://example.com/google-user.png",
          userUrl: "https://google.example/user/google-user-1",
          url: "https://cdn.example.com/drawings/google-saved.jpg",
        },
      },
    ],
    cursor: null,
    hasMore: false,
  });
  await page.goto("/");
  await expect(page.getByRole("img", { name: "Google saved drawing" })).toBeVisible();

  await recorder.step("Switch mock state to anonymous session with empty drawings");
  await mockAnonymousOnlySession(page);
  await mockDrawingsList(page, {
    blobs: [],
    cursor: null,
    hasMore: false,
  });

  await recorder.step("Reload gallery and verify Google drawing is no longer visible in anonymous mode");
  await page.reload();
  await expect(page.getByRole("img", { name: "Google saved drawing" })).toHaveCount(0);
  await expect(page.getByText("Google User")).toHaveCount(0);

  console.log("CODEVALID_TEST_ASSERTION_OK:switching_from_google_to_anonymous");
  await recorder.save(testInfo);
});
