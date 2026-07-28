import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { mockDrawingsList } from "../../helpers/mock-api.js";
import { aiImageOnlyResponse } from "../../mock/mock-data.js";

test("AI-generated image-only creation is retrieved and displayed", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "retrieves_ai_image_only",
    testTitle: "AI-generated image-only creation is retrieved and displayed",
  });

  await recorder.step("Mock GET /api/drawings with AI-only payload", async () => {
    await mockDrawingsList(page, aiImageOnlyResponse);
  });

  await recorder.step("Navigate to homepage", async () => {
    await page.goto("/");
  });

  await recorder.step("Verify creator name and primary preview are rendered", async () => {
    await expect(page.getByText("Jane")).toBeVisible();
    await expect(page.getByAltText("AI-only artwork")).toBeVisible();
  });

  await recorder.step("Verify AI overlay image is rendered when aiImage metadata exists", async () => {
    await expect(page.getByAltText("AI image generated of AI-only artwork")).toBeVisible();
  });

  console.log("CODEVALID_TEST_ASSERTION_OK:retrieves_ai_image_only");
  await recorder.save(testInfo);
});
