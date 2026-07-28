import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { mockDrawingsList } from "../../helpers/mock-api.js";
import { combinedDrawingAndAiResponse } from "../../mock/mock-data.js";

test("Combined original drawing and AI-generated image is retrieved and displayed", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "retrieves_combined_drawing_and_ai_image",
    testTitle: "Combined original drawing and AI-generated image is retrieved and displayed",
  });

  await recorder.step("Mock GET /api/drawings with combined drawing and AI payload", async () => {
    await mockDrawingsList(page, combinedDrawingAndAiResponse);
  });

  await recorder.step("Navigate to homepage", async () => {
    await page.goto("/");
  });

  await recorder.step("Verify creator name and primary drawing preview are rendered", async () => {
    await expect(page.getByText("Alex")).toBeVisible();
    await expect(page.getByAltText("Combined drawing with AI variant")).toBeVisible();
  });

  await recorder.step("Verify AI overlay preview is rendered for combined asset", async () => {
    await expect(page.getByAltText("AI image generated of Combined drawing with AI variant")).toBeVisible();
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:retrieves_combined_drawing_and_ai_image");
  await recorder.save(testInfo);
});
