import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  mockGoogleAuthenticatedSession,
  mockAnonymousOnlySession,
  mockDrawingsList,
} from "../../helpers/mock-api.js";

test("anonymous_and_authenticated_states_are_isolated", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "anonymous_and_authenticated_states_are_isolated",
    testTitle: testInfo.title,
  });

  await recorder.step("Mock Google-authenticated gallery containing only Google drawing");
  await mockGoogleAuthenticatedSession(page);
  await mockDrawingsList(page, {
    blobs: [
      {
        pathname: "drawings/google-only.jpg",
        uploadedAt: "2026-07-28T00:00:00.000Z",
        customMetadata: {
          description: "Google only drawing",
          userProvider: "google",
          userId: "google-user-1",
          userName: "Google User",
          userAvatar: "https://example.com/google-user.png",
          userUrl: "https://google.example/user/google-user-1",
          url: "https://cdn.example.com/drawings/google-only.jpg",
        },
      },
    ],
    cursor: null,
    hasMore: false,
  });

  await recorder.step("Open gallery as Google-authenticated user and verify only Google content is visible");
  await page.goto("/");
  await expect(page.getByRole("img", { name: "Google only drawing" })).toBeVisible();
  await expect(page.getByText("Google User")).toBeVisible();
  await expect(page.getByText("Anonymous Artist")).toHaveCount(0);

  await recorder.step("Switch mocked state to anonymous session with isolated anonymous drawings");
  await mockAnonymousOnlySession(page);
  await mockDrawingsList(page, {
    blobs: [
      {
        pathname: "drawings/anonymous-only.jpg",
        uploadedAt: "2026-07-28T00:00:00.000Z",
        customMetadata: {
          description: "Anonymous only drawing",
          userProvider: "anonymous",
          userId: "anon-local-1",
          userName: "Anonymous Artist",
          userAvatar: "",
          userUrl: "",
          url: "https://cdn.example.com/drawings/anonymous-only.jpg",
        },
      },
    ],
    cursor: null,
    hasMore: false,
  });

  await recorder.step("Reload gallery and verify anonymous session sees only anonymous content");
  await page.reload();
  await expect(page.getByRole("img", { name: "Anonymous only drawing" })).toBeVisible();
  await expect(page.getByText("Anonymous Artist")).toBeVisible();
  await expect(page.getByText("Google User")).toHaveCount(0);
  await expect(page.getByRole("img", { name: "Google only drawing" })).toHaveCount(0);

  console.log("CODEVALID_TEST_ASSERTION_OK:anonymous_and_authenticated_states_are_isolated");
  await recorder.save(testInfo);
});
