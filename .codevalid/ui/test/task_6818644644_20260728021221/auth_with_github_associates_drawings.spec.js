import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  mockGithubAuthenticatedSession,
  mockDrawingUploadSuccess,
  mockDrawingsList,
  drawOnCanvas,
} from "../../helpers/mock-api.js";

test("auth_with_github_associates_drawings", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "auth_with_github_associates_drawings",
    testTitle: testInfo.title,
  });

  await recorder.step("Mock GitHub authenticated session and empty initial drawings list");
  await mockGithubAuthenticatedSession(page);
  await mockDrawingsList(page, { blobs: [], cursor: null, hasMore: false });

  await recorder.step("Mock successful upload response tagged to GitHub identity");
  await mockDrawingUploadSuccess(page, {
    pathname: "drawings/github-drawing-1.jpg",
    customMetadata: {
      description: "GitHub drawing",
      userProvider: "github",
      userId: "github-user-1",
      userName: "GitHub User",
      userAvatar: "https://example.com/github-user.png",
      userUrl: "https://github.com/github-user-1",
      url: "https://cdn.example.com/drawings/github-drawing-1.jpg",
    },
  });

  await recorder.step("Open draw page as GitHub-authenticated user");
  await page.goto("/draw");
  await expect(page.getByRole("button", { name: "Share my drawing" })).toBeVisible();

  await recorder.step("Create and share a drawing");
  await drawOnCanvas(page);
  await page.getByRole("button", { name: "Share my drawing" }).click();

  await recorder.step("Return GitHub-only drawings on the gallery after redirect");
  await mockDrawingsList(page, {
    blobs: [
      {
        pathname: "drawings/github-drawing-1.jpg",
        uploadedAt: "2026-07-28T00:00:00.000Z",
        customMetadata: {
          description: "GitHub drawing",
          userProvider: "github",
          userId: "github-user-1",
          userName: "GitHub User",
          userAvatar: "https://example.com/github-user.png",
          userUrl: "https://github.com/github-user-1",
          url: "https://cdn.example.com/drawings/github-drawing-1.jpg",
        },
      },
    ],
    cursor: null,
    hasMore: false,
  });

  await recorder.step("Verify saved GitHub drawing appears and non-GitHub drawings do not");
  await expect(page).toHaveURL(/\/$/);
  await expect(page.getByRole("img", { name: "GitHub drawing" })).toBeVisible();
  await expect(page.getByText("GitHub User")).toBeVisible();
  await expect(page.getByText("Google User")).toHaveCount(0);
  await expect(page.getByText("Anonymous Artist")).toHaveCount(0);

  console.log("CODEVALID_TEST_ASSERTION_OK:auth_with_github_associates_drawings");
  await recorder.save(testInfo);
});
