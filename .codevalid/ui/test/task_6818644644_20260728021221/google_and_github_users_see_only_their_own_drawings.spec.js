import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  mockGoogleAuthenticatedSession,
  mockGithubAuthenticatedSession,
  mockDrawingsList,
} from "../../helpers/mock-api.js";

test("google_and_github_users_see_only_their_own_drawings", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "google_and_github_users_see_only_their_own_drawings",
    testTitle: testInfo.title,
  });

  await recorder.step("Mock Google user gallery with only Google drawing");
  await mockGoogleAuthenticatedSession(page);
  await mockDrawingsList(page, {
    blobs: [
      {
        pathname: "drawings/google-owned.jpg",
        uploadedAt: "2026-07-28T00:00:00.000Z",
        customMetadata: {
          description: "Google owned drawing",
          userProvider: "google",
          userId: "google-user-1",
          userName: "Google User",
          userAvatar: "https://example.com/google-user.png",
          userUrl: "https://google.example/user/google-user-1",
          url: "https://cdn.example.com/drawings/google-owned.jpg",
        },
      },
    ],
    cursor: null,
    hasMore: false,
  });
  await page.goto("/");
  await expect(page.getByRole("img", { name: "Google owned drawing" })).toBeVisible();
  await expect(page.getByText("Google User")).toBeVisible();
  await expect(page.getByText("GitHub User")).toHaveCount(0);

  await recorder.step("Switch to GitHub user gallery with only GitHub drawing");
  await mockGithubAuthenticatedSession(page);
  await mockDrawingsList(page, {
    blobs: [
      {
        pathname: "drawings/github-owned.jpg",
        uploadedAt: "2026-07-28T00:00:00.000Z",
        customMetadata: {
          description: "GitHub owned drawing",
          userProvider: "github",
          userId: "github-user-1",
          userName: "GitHub User",
          userAvatar: "https://example.com/github-user.png",
          userUrl: "https://github.com/github-user-1",
          url: "https://cdn.example.com/drawings/github-owned.jpg",
        },
      },
    ],
    cursor: null,
    hasMore: false,
  });
  await page.reload();
  await expect(page.getByRole("img", { name: "GitHub owned drawing" })).toBeVisible();
  await expect(page.getByText("GitHub User")).toBeVisible();
  await expect(page.getByText("Google User")).toHaveCount(0);
  await expect(page.getByRole("img", { name: "Google owned drawing" })).toHaveCount(0);

  console.log("CODEVALID_TEST_ASSERTION_OK:google_and_github_users_see_only_their_own_drawings");
  await recorder.save(testInfo);
});
