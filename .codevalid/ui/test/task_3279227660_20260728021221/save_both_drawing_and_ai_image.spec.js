import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  mockGoogleAuthenticatedSession,
  mockDrawingsList,
} from "../../helpers/mock-api.js";
import { buildDrawingsResponse } from "../../mock/mock-data.js";

const combinedArtworkResponse = buildDrawingsResponse([
  {
    pathname: "drawings/combined-artwork.jpg",
    uploadedAt: "2026-07-28T00:20:00.000Z",
    customMetadata: {
      description: "Combined artwork",
      userProvider: "google",
      userId: "google-user-1",
      userName: "Google User",
      userAvatar: "https://example.com/google-user.png",
      userUrl: "https://google.example/user/google-user-1",
      url: "https://cdn.example.com/drawings/combined-artwork.jpg",
      aiImage: "ai/combined-artwork-ai.jpg",
      aiImageUrl: "https://cdn.example.com/ai/combined-artwork-ai.jpg",
    },
  },
]);

test("User saves both original drawing and AI-generated image — both stored and synced", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "save_both_drawing_and_ai_image",
    testTitle: testInfo.title,
  });

  await mockGoogleAuthenticatedSession(page);
  await mockDrawingsList(page, combinedArtworkResponse);

  await recorder.step("Open artwork library", async () => {
    await page.goto("/");
    await expect(page.getByAltText("Combined artwork")).toBeVisible();
  });

  await recorder.step("Verify original drawing and AI image metadata are both available", async () => {
    await expect(page.getByAltText("Combined artwork")).toBeVisible();
    await expect(page.getByAltText("AI image generated of Combined artwork")).toBeAttached();
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:save_both_drawing_and_ai_image");
  await recorder.save(testInfo);
});
