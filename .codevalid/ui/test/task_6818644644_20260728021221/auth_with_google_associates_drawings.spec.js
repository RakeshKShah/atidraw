import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  mockGoogleAuthenticatedSession,
  mockDrawingUploadSuccess,
  mockDrawingsList,
  drawOnCanvas,
} from "../../helpers/mock-api.js";

test("auth_with_google_associates_drawings", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "auth_with_google_associates_drawings",
    testTitle: testInfo.title,
  });

  await recorder.step("Mock Google authenticated session and initial empty gallery");
  await mockGoogleAuthenticatedSession(page);
  await mockDrawingsList(page, { blobs: [], cursor: null, hasMore: false });

  await recorder.step("Mock successful upload for Google identity");
  await mockDrawingUploadSuccess(page, {
    pathname: "drawings/google-drawing-1.jpg",
    customMetadata: {
      description: "Google drawing",
      userProvider: "google",
      userId: "google-user-1",
      userName: "Google User",
      userAvatar: "https://example.com/google-user.png",
      userUrl: "https://google.example/user/google-user-1",
      url: "https://cdn.example.com/drawings/google-drawing-1.jpg",
    },
  });

  await recorder.step("Open draw page and confirm Google sign-in reached drawing surface");
  await page.goto("/draw");
  await expect(page.getByText("Create a drawing and share it with the world!")).toBeVisible();
  await expect(page.getByRole("button", { name: "Share my drawing" })).toBeVisible();

  await recorder.step("Create a drawing on the canvas and share it");
  await drawOnCanvas(page);
  await expect(page.getByRole("button", { name: "Share my drawing" })).toBeEnabled();
  await page.getByRole("button", { name: "Share my drawing" }).click();

  await recorder.step("Mock gallery after re-opening with only Google-owned drawing visible");
  await mockDrawingsList(page, {
    blobs: [
      {
        pathname: "drawings/google-drawing-1.jpg",
        uploadedAt: "2026-07-28T00:00:00.000Z",
        customMetadata: {
          description: "Google drawing",
          userProvider: "google",
          userId: "google-user-1",
          userName: "Google User",
          userAvatar: "https://example.com/google-user.png",
          userUrl: "https://google.example/user/google-user-1",
          url: "https://cdn.example.com/drawings/google-drawing-1.jpg",
        },
      },
    ],
    cursor: null,
    hasMore: false,
  });

  await recorder.step("Verify redirect to gallery and that the saved Google drawing is listed");
  await expect(page).toHaveURL(/\/$/);
  await expect(page.getByRole("img", { name: "Google drawing" })).toBeVisible();
  await expect(page.getByText("Google User")).toBeVisible();
  await expect(page.getByRole("img", { name: "Google drawing" })).toHaveAttribute(
    "src",
    "https://cdn.example.com/drawings/google-drawing-1.jpg"
  );
  await expect(page.getByText("GitHub User")).toHaveCount(0);
  await expect(page.getByText("Anonymous Artist")).toHaveCount(0);

  console.log("CODEVALID_TEST_ASSERTION_OK:auth_with_google_associates_drawings");
  await recorder.save(testInfo);
});
