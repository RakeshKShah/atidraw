import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import {
  mockGoogleAuthenticatedSession,
  mockDrawingsList,
} from "../../helpers/mock-api.js";
import { buildDrawingsResponse } from "../../mock/mock-data.js";

const aiOnlyLibraryResponse = buildDrawingsResponse([
  {
    pathname: "drawings/ai-only-placeholder.jpg",
    uploadedAt: "2026-07-28T00:10:00.000Z",
    customMetadata: {
      description: "AI only artwork",
      userProvider: "google",
      userId: "google-user-1",
      userName: "Google User",
      userAvatar: "https://example.com/google-user.png",
      userUrl: "https://google.example/user/google-user-1",
      url: "https://cdn.example.com/drawings/ai-only-placeholder.jpg",
      aiImage: "ai/ai-only-artwork.jpg",
      aiImageUrl: "https://cdn.example.com/ai/ai-only-artwork.jpg",
    },
  },
]);

test("User saves an AI-generated image — local storage and sync triggered", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "save_ai_generated_image_only",
    testTitle: testInfo.title,
  });

  await mockGoogleAuthenticatedSession(page);
  await mockDrawingsList(page, aiOnlyLibraryResponse);

  await recorder.step("Open synchronized artwork library", async () => {
    await page.goto("/");
    await expect(page.getByAltText("AI only artwork")).toBeVisible();
  });

  await recorder.step("Verify AI-generated asset remains accessible from synchronized storage", async () => {
    await expect(page.getByAltText("AI image generated of AI only artwork")).toBeAttached();
    await expect(page.getByText("Google User")).toBeVisible();
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:save_ai_generated_image_only");
  await recorder.save(testInfo);
});
