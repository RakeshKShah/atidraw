import { test, expect } from "@playwright/test";
import { ExecutionRecorder } from "../../helpers/execution-recorder.js";
import { mockGoogleAuthenticatedSession, drawOnCanvas } from "../../helpers/mock-api.js";
import { fulfillJson } from "../../mock/mock-server.js";
import { altTextUploadFixtures } from "../../mock/alt-text-upload-fixtures.js";

test("Alt text generation requires no user input or interaction", async ({ page }, testInfo) => {
  const recorder = new ExecutionRecorder({
    testId: "no_manual_alt_text_input_required",
    testTitle: testInfo.title,
  });

  try {
    await recorder.step("Mock authenticated draw session");
    await mockGoogleAuthenticatedSession(page);

    await recorder.step("Mock upload success with generated alt text");
    await page.route(/^https?:\/\/[^/]+\/api\/upload(?:\?.*)?$/, async (route) => {
      expect(route.request().method()).toBe("POST");
      await fulfillJson(route, altTextUploadFixtures.descriptiveLandscape, 200);
    });

    await recorder.step("Open draw page");
    await page.goto("/draw");

    await recorder.step("Assert there is no manual alt text input UI");
    await expect(page.getByRole("button", { name: "Share my drawing" })).toBeVisible();
    await expect(page.locator('input[name="altText"]')).toHaveCount(0);
    await expect(page.locator('textarea[name="altText"]')).toHaveCount(0);
    await expect(page.getByRole("textbox", { name: /alt/i })).toHaveCount(0);
    await expect(page.getByText(/enter alt text/i)).toHaveCount(0);
    await expect(page.getByText(/confirm alt text/i)).toHaveCount(0);

    await recorder.step("Create and save a drawing without extra user interaction");
    await drawOnCanvas(page);
    await page.getByRole("button", { name: "Share my drawing" }).click();

    await recorder.step("Verify save completes without any alt text prompt");
    await page.waitForURL("/");
    await expect(page.getByText(/enter alt text/i)).toHaveCount(0);
    await expect(page.getByText(/confirm alt text/i)).toHaveCount(0);
    await expect(page.getByRole("dialog")).toHaveCount(0);

    console.log("CODEVALID_TEST_ASSERTION_OK:no_manual_alt_text_input_required");
  } finally {
    await recorder.save(testInfo);
  }
});
