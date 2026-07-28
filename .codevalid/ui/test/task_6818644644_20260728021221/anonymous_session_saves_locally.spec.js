import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  mockAnonymousOnlySession,
  mockDrawingsList,
  mockDrawingUploadSuccess,
  drawOnCanvas,
} from "../../helpers/mock-api.js";

test("anonymous_session_saves_locally", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "anonymous_session_saves_locally",
    testTitle: testInfo.title,
  });

  await recorder.step("Mock anonymous-only login state with anonymous sign-in available");
  await mockAnonymousOnlySession(page);
  await page.goto("/draw");

  await recorder.step("Verify anonymous sign-in option is shown");
  await expect(page.getByRole("link", { name: "Sign-in anonymously" })).toBeVisible();
  await expect(page.getByRole("link", { name: "Sign-in with Google" })).toHaveCount(0);
  await expect(page.getByRole("link", { name: "Sign-in with GitHub" })).toHaveCount(0);

  await recorder.step("Enter anonymous draw session");
  await page.getByRole("link", { name: "Sign-in anonymously" }).click();
  await expect(page).toHaveURL(/\/draw$/);
  await expect(page.getByRole("button", { name: "Share my drawing" })).toBeVisible();

  await recorder.step("Mock upload and gallery responses for anonymous local context");
  await mockDrawingUploadSuccess(page, {
    pathname: "drawings/anonymous-drawing-1.jpg",
    customMetadata: {
      description: "Anonymous drawing",
      userProvider: "anonymous",
      userId: "anon-local-1",
      userName: "Anonymous Artist",
      userAvatar: "",
      userUrl: "",
      url: "https://cdn.example.com/drawings/anonymous-drawing-1.jpg",
    },
  });
  await mockDrawingsList(page, {
    blobs: [
      {
        pathname: "drawings/anonymous-drawing-1.jpg",
        uploadedAt: "2026-07-28T00:00:00.000Z",
        customMetadata: {
          description: "Anonymous drawing",
          userProvider: "anonymous",
          userId: "anon-local-1",
          userName: "Anonymous Artist",
          userAvatar: "",
          userUrl: "",
          url: "https://cdn.example.com/drawings/anonymous-drawing-1.jpg",
        },
      },
    ],
    cursor: null,
    hasMore: false,
  });

  await recorder.step("Create and share anonymous drawing");
  await drawOnCanvas(page);
  await page.getByRole("button", { name: "Share my drawing" }).click();
  await expect(page).toHaveURL(/\/$/);
  await expect(page.getByRole("img", { name: "Anonymous drawing" })).toBeVisible();

  await recorder.step("Refresh gallery and verify anonymous drawing remains visible in same local context");
  await page.reload();
  await expect(page.getByRole("img", { name: "Anonymous drawing" })).toBeVisible();
  await expect(page.getByText("Anonymous Artist")).toBeVisible();
  await expect(page.getByText("Google User")).toHaveCount(0);
  await expect(page.getByText("GitHub User")).toHaveCount(0);

  console.log("CODEVALID_TEST_ASSERTION_OK:anonymous_session_saves_locally");
  await recorder.save(testInfo);
});
